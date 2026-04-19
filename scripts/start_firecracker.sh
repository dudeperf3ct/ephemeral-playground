#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

if [[ ! -x "$FIRECRACKER_BIN" ]]; then
  echo "ERROR: Firecracker binary missing or not executable: $FIRECRACKER_BIN"
  exit 1
fi

rm -f "$API_SOCKET" "$PID_FILE" "$LOG_FILE"

echo "Starting Firecracker..."
nohup "$FIRECRACKER_BIN" --api-sock "$API_SOCKET" >"$LOG_FILE" 2>&1 </dev/null &
pid="$!"
echo "$pid" >"$PID_FILE"

for _ in $(seq 1 50); do
  if [[ -S "$API_SOCKET" ]]; then
    break
  fi
  sleep 0.1
done

if [[ ! -S "$API_SOCKET" ]]; then
  echo "ERROR: API socket not created: $API_SOCKET"
  tail -n 40 "$LOG_FILE" || true
  exit 1
fi

if ! kill -0 "$pid" 2>/dev/null; then
  echo "ERROR: Firecracker exited during startup."
  tail -n 40 "$LOG_FILE" || true
  exit 1
fi

echo "Firecracker running."
echo "PID:    $pid"
echo "Socket: $API_SOCKET"
echo "Log:    $LOG_FILE"
