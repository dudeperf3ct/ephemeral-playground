#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

API_SOCKET="${API_SOCKET:-/tmp/firecracker.socket}"
PID_FILE="${PID_FILE:-$ROOT_DIR/artifacts/firecracker.pid}"
LOG_FILE="${LOG_FILE:-$ROOT_DIR/artifacts/firecracker.log}"
FIRECRACKER_BIN="${FIRECRACKER_BIN:-$ROOT_DIR/firecracker}"
KERNEL="${KERNEL:-$ROOT_DIR/artifacts/vmlinux.bin}"
ROOTFS="${ROOTFS:-$ROOT_DIR/artifacts/rootfs.ext4}"
BOOT_ARGS="${BOOT_ARGS:-console=ttyS0 reboot=k panic=1}"
SNAPSHOT_DIR="${SNAPSHOT_DIR:-$ROOT_DIR/artifacts/snapshots}"

require_api_socket() {
  if [[ ! -S "$API_SOCKET" ]]; then
    echo "ERROR: Firecracker API socket not found: $API_SOCKET"
    echo "Run: just start-firecracker"
    exit 1
  fi

  # Connection check prevents confusing failures with stale socket files.
  if ! curl --silent --show-error --unix-socket "$API_SOCKET" \
    -o /dev/null "http://localhost/"; then
    echo "ERROR: Firecracker API is not responding on socket: $API_SOCKET"
    exit 1
  fi
}

firecracker_put() {
  local endpoint="$1"
  local payload="$2"
  curl --fail --silent --show-error --unix-socket "$API_SOCKET" \
    -X PUT "http://localhost/$endpoint" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null
}

firecracker_patch() {
  local endpoint="$1"
  local payload="$2"
  curl --fail --silent --show-error --unix-socket "$API_SOCKET" \
    -X PATCH "http://localhost/$endpoint" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null
}
