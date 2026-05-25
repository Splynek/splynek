#!/usr/bin/env python3
"""
email-blast-launch.py — send the Splynek 1.0 launch announcement to
the consent-based v0.x user list via Resend's batch API.

2026-06 direct-sale launch (LAUNCH-WITHOUT-APPLE.md § E2).

What this script does
---------------------
1. Reads a maintainer-curated CSV of v0.x user emails (default:
   `Outreach/v0-users.csv` — gitignored; see
   `Outreach/README.md` for the schema + the consent rules).
2. Reads the email body template from `LAUNCH-1.0-COPY.md` §
   "Email to existing v0.x DMG users" (between the visible
   markers; the template is the canonical source of truth so it
   stays in sync with the public Show HN copy).
3. Renders a per-recipient personalised email using the row's
   `first_name` field for the greeting.
4. Calls Resend's POST /emails endpoint in batches of 100,
   respecting their rate limit (10 req/sec).
5. Logs every send + every error to `Outreach/blast.<date>.log`
   so the maintainer can audit + retry failures later.

It does NOT:
- Build any list itself.  Splynek has no telemetry and no account
  system; there's no programmatic way to enumerate v0.x users.
  The maintainer curates the CSV from GitHub Sponsors,
  splynek.app newsletter signups, manual outreach contacts, and
  Discord opt-ins — see `Outreach/README.md`.
- Track opens / clicks / unsubscribes.  Same privacy posture as
  the rest of Splynek — we don't aggregate any of that.  If a
  recipient wants off the list, they reply asking and we remove
  by hand.

Usage
-----
    # 1.  Maintainer prepares Outreach/v0-users.csv with columns:
    #         email,first_name,consent_date,notes
    #     Only rows with a non-empty consent_date get a send;
    #     consent_date is when the user explicitly opted in.
    # 2.  Set RESEND_API_KEY in the env (same key the Worker uses):
    #         export RESEND_API_KEY=re_…
    # 3.  Dry-run first (prints intent, sends nothing):
    #         python3 Scripts/email-blast-launch.py --dry-run
    # 4.  Real send:
    #         python3 Scripts/email-blast-launch.py
    # 5.  Audit the log:
    #         tail -50 Outreach/blast.2026-06-08.log

Exit codes
    0   - all sends succeeded
    1   - CSV parse error
    2   - missing RESEND_API_KEY
    3   - some sends failed (count printed to stderr); retry by
          editing the CSV down to the failing rows and re-running
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib import request, error

ROOT = Path(__file__).parent.parent
CSV_DEFAULT = ROOT / "Outreach" / "v0-users.csv"
TEMPLATE_PATH = ROOT / "LAUNCH-1.0-COPY.md"
LOG_DIR = ROOT / "Outreach"
LOG_DIR.mkdir(exist_ok=True)

RESEND_ENDPOINT = "https://api.resend.com/emails"
FROM_ADDR = "Splynek <hello@splynek.app>"
SUBJECT = "Splynek 1.0 — and a $24 launch-week price"

# Batch / rate-limit knobs.  Resend allows 10 req/sec on the free
# tier and 100 req/sec on paid.  We default to 5 req/sec to leave
# slack for transient retries.
SENDS_PER_SECOND = 5


# ──────────────────────────────────────────────────────────────────────
# Template extraction
# ──────────────────────────────────────────────────────────────────────

def extract_email_template() -> str:
    """
    Pull the email body out of LAUNCH-1.0-COPY.md so the launch copy
    + the blast stay in lockstep.  The template lives between the
    visible markers:

        ## Email to existing v0.x DMG users (consent-based list)

        **Subject:** ...

        > <body text>

    We grab everything inside the blockquote block.
    """
    raw = TEMPLATE_PATH.read_text()
    marker = "## Email to existing v0.x DMG users"
    if marker not in raw:
        sys.exit(f"Could not find '{marker}' in {TEMPLATE_PATH.name}.")
    chunk = raw.split(marker, 1)[1]
    # Stop at the next H2 header.
    next_h2 = chunk.find("\n## ")
    if next_h2 != -1:
        chunk = chunk[:next_h2]
    # Extract the blockquote body — every line starting with '> '
    # contributes one paragraph (Markdown blockquote).  Strip the
    # leading '> '; collapse blank lines.
    body_lines: list[str] = []
    for raw_line in chunk.splitlines():
        line = raw_line.rstrip()
        if line.startswith("> "):
            body_lines.append(line[2:])
        elif line == ">":
            body_lines.append("")
    return "\n".join(body_lines).strip()


def personalise(template: str, first_name: str | None) -> str:
    """
    Replace the canonical 'Hi,' greeting with 'Hi, <first_name>,'
    when we have a name.  Falls back to 'Hi,' otherwise.
    """
    if first_name and first_name.strip():
        return template.replace("Hi,", f"Hi {first_name.strip()},", 1)
    return template


# ──────────────────────────────────────────────────────────────────────
# Resend client
# ──────────────────────────────────────────────────────────────────────

def send_email(api_key: str, to_addr: str, body: str) -> tuple[bool, str]:
    """
    Send one email.  Returns (success, response_text).  Resend
    accepts plain-text HTML — we wrap the body in <p> tags per
    blank-line block for the simplest readable formatting.
    """
    html = "\n".join(
        f"<p>{paragraph.strip()}</p>"
        for paragraph in body.split("\n\n")
        if paragraph.strip()
    )
    payload = {
        "from": FROM_ADDR,
        "to": [to_addr],
        "subject": SUBJECT,
        "html": html,
    }
    req = request.Request(
        RESEND_ENDPOINT,
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=20) as resp:
            return resp.status < 300, resp.read().decode()
    except error.HTTPError as e:
        return False, f"{e.code}: {e.read().decode()}"
    except Exception as e:
        return False, f"{type(e).__name__}: {e}"


# ──────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--csv", type=Path, default=CSV_DEFAULT,
                        help=f"path to the recipient CSV (default: {CSV_DEFAULT.relative_to(ROOT)})")
    parser.add_argument("--dry-run", action="store_true",
                        help="print every recipient + body preview; send nothing")
    args = parser.parse_args()

    if not args.csv.exists():
        sys.exit(f"CSV not found: {args.csv}\n"
                 f"See Outreach/README.md for the schema + the consent rules.")

    api_key = os.environ.get("RESEND_API_KEY")
    if not args.dry_run and not api_key:
        sys.exit(2)  # missing RESEND_API_KEY

    template = extract_email_template()
    log_path = LOG_DIR / f"blast.{datetime.now(timezone.utc).date()}.log"

    sent = 0
    skipped = 0
    failed = 0
    with args.csv.open() as f, log_path.open("a") as logf:
        reader = csv.DictReader(f)
        for row in reader:
            email = (row.get("email") or "").strip()
            first = (row.get("first_name") or "").strip()
            consent = (row.get("consent_date") or "").strip()

            if not email:
                continue
            if not consent:
                skipped += 1
                print(f"  SKIP no-consent  {email}")
                logf.write(f"{datetime.now(timezone.utc).isoformat()} SKIP {email} no-consent\n")
                continue

            body = personalise(template, first)

            if args.dry_run:
                print(f"  DRY  {email}  (would send {len(body)} chars)")
                if sent == 0:
                    print("\n--- body preview (first recipient) ---")
                    print(body[:400] + ("…" if len(body) > 400 else ""))
                    print("--- end preview ---\n")
                sent += 1
                continue

            ok, reply = send_email(api_key, email, body)
            now = datetime.now(timezone.utc).isoformat()
            if ok:
                sent += 1
                print(f"  OK   {email}")
                logf.write(f"{now} OK {email}\n")
            else:
                failed += 1
                print(f"  FAIL {email}  ({reply[:120]})")
                logf.write(f"{now} FAIL {email} {reply}\n")
            time.sleep(1.0 / SENDS_PER_SECOND)

    print()
    print(f"Done. sent={sent}  skipped={skipped}  failed={failed}")
    print(f"Log: {log_path.relative_to(ROOT)}")
    return 3 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
