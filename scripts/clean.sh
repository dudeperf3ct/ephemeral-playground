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
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    stop_firecracker_process "$pid"
  fi
fi

mapfile -t discovered_pids < <(list_firecracker_pids_for_socket)
if [[ "${#discovered_pids[@]}" -gt 0 ]]; then
  echo "Found Firecracker process(es) without pid file: ${discovered_pids[*]}"
  for pid in "${discovered_pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      stop_firecracker_process "$pid" || true
    fi
  done
fi

mapfile -t remaining_pids < <(list_firecracker_pids_for_socket)
can_remove_runtime_files=true
if [[ "${#remaining_pids[@]}" -eq 0 ]]; then
  if [[ -x "$SCRIPT_DIR/network_down.sh" ]]; then
    "$SCRIPT_DIR/network_down.sh" || true
  fi
else
  echo "WARN: Firecracker still running (${remaining_pids[*]}). Skipping network teardown."
  can_remove_runtime_files=false
fi

# Explicit known files.
if [[ "$can_remove_runtime_files" == "true" ]]; then
  remove_path "$API_SOCKET"
  remove_path "$PID_FILE"
else
  echo "Skipping API socket/pid cleanup while Firecracker is still running."
fi
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
