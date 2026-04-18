#!/usr/bin/env bash
#
# End-to-end integration test — wraps integration-test.py so the
# invocation line in CONTRIBUTING.md / HANDOFF.md stays stable even
# if the test internals move to another language.
#
# Usage:
#   ./Scripts/integration-test.sh [--launch]
#
# Exits 0 on pass, non-zero on failure.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd )"

cd "${REPO_ROOT}"
exec python3 "${SCRIPT_DIR}/integration-test.py" "$@"
