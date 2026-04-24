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
TAP_DEV="${TAP_DEV:-tap0}"
TAP_IP="${TAP_IP:-172.16.0.1}"
GUEST_IP="${GUEST_IP:-172.16.0.2}"
TAP_CIDR="${TAP_CIDR:-30}"
GUEST_NETMASK="${GUEST_NETMASK:-255.255.255.252}"
GUEST_IFACE="${GUEST_IFACE:-eth0}"
GUEST_DNS_1="${GUEST_DNS_1-8.8.8.8}"
GUEST_DNS_2="${GUEST_DNS_2-1.1.1.1}"
FC_IFACE_ID="${FC_IFACE_ID:-net1}"
FC_MAC="${FC_MAC:-06:00:AC:10:00:02}"
HOST_IFACE="${HOST_IFACE:-}"
IPTABLES_BIN="${IPTABLES_BIN:-}"

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

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Missing required command: $cmd"
    exit 1
  fi
}

run_as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    require_cmd sudo
    sudo "$@"
  fi
}

discover_host_iface() {
  if [[ -n "$HOST_IFACE" ]]; then
    echo "$HOST_IFACE"
    return
  fi

  if command -v ip >/dev/null 2>&1; then
    ip route list default 2>/dev/null | awk 'NR==1 {print $5}'
  fi
}

iptables_cmd() {
  if [[ -n "$IPTABLES_BIN" ]]; then
    echo "$IPTABLES_BIN"
    return
  fi

  if command -v iptables-nft >/dev/null 2>&1; then
    echo "iptables-nft"
    return
  fi

  if command -v iptables >/dev/null 2>&1; then
    echo "iptables"
    return
  fi

  echo ""
}

wait_for_pid_exit() {
  local pid="$1"
  local attempts="${2:-50}"

  for _ in $(seq 1 "$attempts"); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.1
  done

  return 1
}

stop_firecracker_process() {
  local pid="$1"

  if ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi

  echo "Stopping Firecracker (pid: $pid)..."
  kill "$pid"

  if wait_for_pid_exit "$pid" 50; then
    return 0
  fi

  echo "Firecracker did not exit after SIGTERM; sending SIGKILL..."
  kill -9 "$pid" 2>/dev/null || true
  wait_for_pid_exit "$pid" 20 || true
}

list_firecracker_pids_for_socket() {
  ps -eo pid=,comm=,args= | awk -v sock="$API_SOCKET" '
    $2 == "firecracker" && index($0, "--api-sock") && index($0, sock) { print $1 }
  '
}

boot_args_with_guest_net() {
  local args="$BOOT_ARGS"
  local ip_arg="${GUEST_IP}::${TAP_IP}:${GUEST_NETMASK}::${GUEST_IFACE}:off"
  if [[ -n "$GUEST_DNS_1" || -n "$GUEST_DNS_2" ]]; then
    ip_arg+=":${GUEST_DNS_1}:${GUEST_DNS_2}"
  fi
  args+=" ip=${ip_arg}"
  echo "$args"
}
