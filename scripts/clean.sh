#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

removed=0

remove_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    rm -rf "$path"
    echo "Removed: $path"
    removed=$((removed + 1))
  fi
}

echo "Cleaning Firecracker host-side state..."

# Stop a running Firecracker process if we have its PID.
if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "Stopping Firecracker (pid: $pid)..."
    kill "$pid"
    wait "$pid" 2>/dev/null || true
  fi
fi

# Explicit known files.
remove_path "$API_SOCKET"
remove_path "$PID_FILE"
remove_path "$LOG_FILE"
remove_path "$SNAPSHOT_DIR"

# Metrics, snapshot, and experiment scratch files.
shopt -s nullglob
for path in \
  "$ROOT_DIR"/artifacts/firecracker*.log \
  "$ROOT_DIR"/artifacts/metrics* \
  "$ROOT_DIR"/artifacts/*.metrics \
  "$ROOT_DIR"/artifacts/*.fifo \
  "$ROOT_DIR"/artifacts/snapshot* \
  "$ROOT_DIR"/artifacts/*.snap \
  "$ROOT_DIR"/artifacts/*.vmstate \
  "$ROOT_DIR"/artifacts/*.mem \
  "$ROOT_DIR"/artifacts/*.vmem \
  "$ROOT_DIR"/artifacts/*.meta \
  "$ROOT_DIR"/artifacts/snapshots
do
  remove_path "$path"
done

# Temp files created by firecracker_install.sh downloads/extraction.
for path in /tmp/firecracker-v*.tgz /tmp/firecracker-v*; do
  remove_path "$path"
done
shopt -u nullglob

echo "Clean complete. Removed $removed path(s)."
