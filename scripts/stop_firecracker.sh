#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    stop_firecracker_process "$pid"
  else
    echo "No running process for pid in $PID_FILE."
  fi
  rm -f "$PID_FILE"
else
  echo "No pid file found."
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
if [[ "${#remaining_pids[@]}" -gt 0 ]]; then
  echo "WARN: Firecracker still running (${remaining_pids[*]}). Skipping network teardown."
  echo "Stop the remaining process(es) and rerun: just network-down"
else
  rm -f "$API_SOCKET"
  if [[ -x "$SCRIPT_DIR/network_down.sh" ]]; then
    "$SCRIPT_DIR/network_down.sh"
  fi
fi

echo "Stopped."
