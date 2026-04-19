#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "Stopping Firecracker (pid: $pid)..."
    kill "$pid"
    wait "$pid" 2>/dev/null || true
  else
    echo "No running process for pid in $PID_FILE."
  fi
  rm -f "$PID_FILE"
else
  echo "No pid file found."
fi

rm -f "$API_SOCKET"
echo "Stopped."
