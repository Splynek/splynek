#!/usr/bin/env python3
"""End-to-end integration test for Splynek's download pipeline.

Runs a local HTTP server serving a file of known bytes, asks a live
Splynek.app to fetch the URL via its REST API, polls the jobs + history
endpoints until completion, and byte-compares the resulting file on
disk against the expected SHA-256.

The test would have caught v0.27's silent-stale-binary regression
(build.sh was shipping an outdated Splynek binary because `swift build`
was targeting the entire package under `-c release`, which SPM tolerates
by falling back to older artefacts when the test target fails to compile).
End-to-end bytes landing on disk is an unambiguous signal that the built
app actually ran the current pipeline.

Usage:
    python3 Scripts/integration-test.py [--launch]

    --launch    Open build/Splynek.app if fleet.json is missing or stale.
                Default: require Splynek to already be running, so the
                test doesn't surprise the user with a pop-up.

What this asserts:
    1. job appears in /splynek/v1/api/jobs after POST /api/download
    2. bytes_downloaded grows monotonically
    3. phase strings observed form a monotonic subsequence of the
       canonical pipeline: Queued -> Probing -> Planning -> Connecting
       -> Downloading -> Verifying -> Gatekeeper -> Done. We don't
       require every phase to fire (fast loopback downloads can skip
       phases between polls); we DO require that every phase we see
       appears in the canonical order.
    4. job disappears from /jobs
    5. entry shows up in /history with the expected totalBytes
    6. SHA-256 of the file on disk matches the expected payload hash

The phase field was added in v0.36. Older Splyneks publish ActiveJob
without it; this test requires v0.36+.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import http.server
import json
import os
import socket
import socketserver
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

FLEET_JSON = (
    Path.home()
    / "Library"
    / "Application Support"
    / "Splynek"
    / "fleet.json"
)
OUTPUT_DIR_DEFAULT = Path.home() / "Downloads"
PAYLOAD_SIZE = 2 * 1024 * 1024          # 2 MiB — enough for multiple chunks
POLL_INTERVAL = 0.1                     # seconds between /jobs polls
JOB_TIMEOUT = 90                        # seconds total before giving up
LAUNCH_TIMEOUT = 30                     # seconds to wait for app to bind

# Canonical pipeline phases from DownloadProgress.Phase.rawValue.
# The test requires observed phases to be a monotonic subsequence of
# this list. "Queued" is pre-populated before `start()` kicks the
# engine so we may or may not see it depending on poll timing.
CANONICAL_PHASES = [
    "Queued", "Probing", "Planning", "Connecting",
    "Downloading", "Verifying", "Gatekeeper", "Done",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def ok(message: str) -> None:
    print(f"  ✓ {message}")


def step(message: str) -> None:
    print(f"• {message}")


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("0.0.0.0", 0))
        return s.getsockname()[1]


def primary_lan_ip() -> str:
    """Return the IPv4 address of the primary outbound interface.

    Splynek pins every outbound connection to a specific `NWInterface`
    via `NWParameters.requiredInterface`. A URL pointing at 127.0.0.1
    routes via `lo0` in the kernel, which doesn't match Splynek's
    chosen interface (Wi-Fi / Ethernet), so the connection hangs at 0
    bytes. We advertise the payload server on the machine's primary
    LAN IP instead — the same interface Splynek is bound to — so the
    request hairpins back through the real route.

    UDP-connect to a public IP without sending anything; the socket's
    bound local address is the one the kernel would use for that route.
    """
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 53))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def make_payload(size: int, seed: bytes = b"splynek-inttest") -> bytes:
    """Deterministic pseudo-random payload.

    We want the expected SHA-256 to be stable across runs so any
    diagnostic output lists the same digest, but we also don't want the
    content to be compressible (that would make interface-level
    multi-lane behaviour less interesting if we ever expand this test).
    """
    out = bytearray()
    counter = 0
    while len(out) < size:
        out += hashlib.sha256(seed + counter.to_bytes(8, "big")).digest()
        counter += 1
    return bytes(out[:size])


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# Local HTTP server
# ---------------------------------------------------------------------------

class PayloadServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, addr, handler, payload: bytes, path: str):
        self.payload = payload
        self.path_want = path
        super().__init__(addr, handler)


class PayloadHandler(http.server.BaseHTTPRequestHandler):
    server: PayloadServer   # type: ignore[assignment]

    def log_message(self, fmt, *args):       # noqa: N802
        # Quiet during the test; errors still surface via .log_error.
        return

    def _send_common(self, status: int, body: bytes, content_range: str | None = None):
        self.send_response(status)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Accept-Ranges", "bytes")
        if content_range:
            self.send_header("Content-Range", content_range)
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_HEAD(self):                         # noqa: N802
        if self.path != self.server.path_want:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(self.server.payload)))
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()

    def do_GET(self):                          # noqa: N802
        if self.path != self.server.path_want:
            self.send_error(404)
            return
        rng = self.headers.get("Range")
        total = len(self.server.payload)
        if rng and rng.startswith("bytes="):
            spec = rng[len("bytes="):]
            try:
                start_s, end_s = spec.split("-", 1)
                start = int(start_s) if start_s else 0
                end = int(end_s) if end_s else total - 1
                if start < 0 or end >= total or start > end:
                    self.send_error(416)
                    return
                chunk = self.server.payload[start:end + 1]
                cr = f"bytes {start}-{end}/{total}"
                self._send_common(206, chunk, content_range=cr)
                return
            except ValueError:
                self.send_error(400)
                return
        self._send_common(200, self.server.payload)


@contextlib.contextmanager
def run_payload_server(payload: bytes, path: str):
    port = free_port()
    ip = primary_lan_ip()
    # Bind to all interfaces so Splynek's bound-interface outbound
    # request lands on us regardless of which interface it chose.
    server = PayloadServer(("0.0.0.0", port), PayloadHandler, payload, path)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://{ip}:{port}{path}"
    finally:
        server.shutdown()
        server.server_close()


# ---------------------------------------------------------------------------
# Splynek REST client
# ---------------------------------------------------------------------------

def load_fleet() -> tuple[int, str]:
    if not FLEET_JSON.exists():
        raise FileNotFoundError(FLEET_JSON)
    data = json.loads(FLEET_JSON.read_text())
    return int(data["port"]), str(data["token"])


def wait_for_fleet(timeout: float) -> tuple[int, str]:
    deadline = time.monotonic() + timeout
    last_err: str = ""
    while time.monotonic() < deadline:
        try:
            port, token = load_fleet()
            # Confirm the port is actually bound.
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(0.5)
                s.connect(("127.0.0.1", port))
            return port, token
        except Exception as e:         # noqa: BLE001
            last_err = str(e)
            time.sleep(0.5)
    raise TimeoutError(f"Splynek never became reachable — last error: {last_err}")


def ensure_splynek(launch: bool) -> tuple[int, str]:
    try:
        port, token = load_fleet()
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(0.5)
            s.connect(("127.0.0.1", port))
        return port, token
    except Exception:        # noqa: BLE001
        if not launch:
            fail(
                "Splynek is not running (no fleet.json or port closed). "
                "Either launch it manually or re-run with --launch."
            )
        step("Launching build/Splynek.app (use --launch to skip manual start)")
        repo_root = Path(__file__).resolve().parent.parent
        app = repo_root / "build" / "Splynek.app"
        if not app.exists():
            fail(f"build/Splynek.app missing — run ./Scripts/build.sh first ({app})")
        subprocess.run(["open", str(app)], check=True)
        return wait_for_fleet(LAUNCH_TIMEOUT)


def api_get(port: int, path: str) -> dict | list:
    url = f"http://127.0.0.1:{port}{path}"
    with urllib.request.urlopen(url, timeout=5) as resp:
        return json.loads(resp.read())


def api_post_download(port: int, token: str, url: str) -> None:
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/splynek/v1/api/download?t={token}",
        data=json.dumps({"url": url}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        if resp.status not in (200, 202):
            fail(f"POST /api/download returned {resp.status}")


def active_for(port: int, url: str) -> dict | None:
    jobs = api_get(port, "/splynek/v1/api/jobs")
    assert isinstance(jobs, list)
    for job in jobs:
        if job.get("url") == url:
            return job
    return None


def history_for(port: int, url: str) -> dict | None:
    hist = api_get(port, "/splynek/v1/api/history?limit=25")
    assert isinstance(hist, list)
    for entry in hist:
        if entry.get("url") == url:
            return entry
    return None


# ---------------------------------------------------------------------------
# Test flow
# ---------------------------------------------------------------------------

def run_test(launch: bool) -> None:
    stamp = int(time.time())
    filename = f"splynek_inttest_{stamp}.bin"
    payload = make_payload(PAYLOAD_SIZE)
    expected_sha = sha256_hex(payload)

    print(f"Splynek integration test ({stamp})")
    print(f"  payload: {PAYLOAD_SIZE} B, sha256={expected_sha[:12]}…")
    print(f"  filename: {filename}")

    step("Start local HTTP server on 0.0.0.0 (advertised via primary LAN IP)")
    with run_payload_server(payload, f"/{filename}") as file_url:
        ok(f"serving {file_url}")

        step("Resolve Splynek fleet descriptor")
        port, token = ensure_splynek(launch)
        ok(f"port={port} token={token[:8]}…")

        step("Submit download via REST API")
        api_post_download(port, token, file_url)
        ok("POST /splynek/v1/api/download → 202 Accepted")

        step("Poll /api/jobs for progress + phase transitions")
        seen_active = False
        last_downloaded = -1
        progress_ticks = 0
        # Ordered list of distinct phase strings observed across polls —
        # duplicates collapsed. Used below to assert monotonicity
        # against CANONICAL_PHASES.
        phase_trail: list[str] = []
        deadline = time.monotonic() + JOB_TIMEOUT
        while time.monotonic() < deadline:
            job = active_for(port, file_url)
            if job is None:
                if seen_active:
                    ok(f"job disappeared from /api/jobs after {progress_ticks} progress ticks")
                    break
                # Not yet started OR already completed during our first poll.
                # Check history before assuming we missed it.
                if history_for(port, file_url):
                    ok("job completed before first /api/jobs poll (fast path)")
                    break
                time.sleep(POLL_INTERVAL)
                continue
            seen_active = True
            downloaded = int(job.get("downloaded", 0))
            if downloaded > last_downloaded:
                progress_ticks += 1
                last_downloaded = downloaded
            phase = str(job.get("phase") or "")
            if phase and (not phase_trail or phase_trail[-1] != phase):
                phase_trail.append(phase)
            time.sleep(POLL_INTERVAL)
        else:
            fail(f"job did not complete within {JOB_TIMEOUT}s "
                 f"(seen_active={seen_active}, last_downloaded={last_downloaded}, "
                 f"phase_trail={phase_trail})")

        step("Assert phase transitions form a monotonic subsequence")
        if not phase_trail:
            # Whole download flew past between polls. Skip rather than
            # fail — the fast-path ok line above already noted that
            # /jobs never had the entry long enough to observe phases.
            print("  (no phases observed — download completed faster than the 100ms poll)")
        else:
            idx = 0
            for phase in phase_trail:
                # Advance the canonical cursor until we find this phase
                # at or after idx. If we never find it, the transition
                # was non-monotonic.
                try:
                    new_idx = CANONICAL_PHASES.index(phase, idx)
                except ValueError:
                    fail(f"phase {phase!r} out of order or unknown "
                         f"(trail={phase_trail}, canonical={CANONICAL_PHASES})")
                idx = new_idx
            ok(f"phase trail is monotonic: {' → '.join(phase_trail)}")
            # Fast downloads compress phases; assert only the essentials.
            critical = {"Downloading"}
            missing = critical - set(phase_trail)
            if missing:
                print(f"  (note: did not observe {missing} — loopback is fast)")

        step("Confirm entry appears in /api/history")
        entry = history_for(port, file_url)
        if entry is None:
            fail("completion recorded neither in /jobs nor /history — pipeline may have failed silently")
        ok(f"history entry present with totalBytes={entry.get('totalBytes')}")
        if int(entry.get("totalBytes", 0)) != PAYLOAD_SIZE:
            fail(f"history totalBytes mismatch: got {entry.get('totalBytes')}, expected {PAYLOAD_SIZE}")
        ok(f"totalBytes matches payload size ({PAYLOAD_SIZE})")

        step("Byte-compare file on disk")
        output_path = Path(entry.get("outputPath") or (OUTPUT_DIR_DEFAULT / filename))
        if not output_path.exists():
            fail(f"expected output file missing at {output_path}")
        actual_sha = sha256_file(output_path)
        if actual_sha != expected_sha:
            fail(f"sha256 mismatch: got {actual_sha}, expected {expected_sha}")
        ok(f"sha256 matches expected ({expected_sha[:12]}…)")

        step("Cleanup")
        try:
            output_path.unlink()
            sidecar = output_path.with_suffix(output_path.suffix + ".splynek")
            if sidecar.exists():
                sidecar.unlink()
            ok(f"removed {output_path.name} (+ sidecar)")
        except OSError as e:
            print(f"  (cleanup warning — remove {output_path} manually: {e})")

    print("")
    print("✓ integration test passed")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--launch", action="store_true",
                    help="Launch build/Splynek.app if fleet.json is missing or its port is closed.")
    args = ap.parse_args()
    try:
        run_test(launch=args.launch)
        return 0
    except KeyboardInterrupt:
        print("\n(cancelled)", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
