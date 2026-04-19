#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "Firecracker process running (pid: $pid)."
  else
    echo "Stale pid file: $PID_FILE (pid $pid not running)."
  fi
else
  echo "No pid file: $PID_FILE"
fi

if [[ -S "$API_SOCKET" ]]; then
  if curl --silent --show-error --unix-socket "$API_SOCKET" -o /dev/null "http://localhost/"; then
    echo "API socket present and responding: $API_SOCKET"
  else
    echo "API socket present but not responding: $API_SOCKET"
  fi
else
  echo "API socket missing: $API_SOCKET"
fi

if [[ -f "$LOG_FILE" ]]; then
  echo "Recent logs:"
  tail -n 20 "$LOG_FILE" || true
fi
