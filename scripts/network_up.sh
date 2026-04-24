#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmd ip
host_iface="$(discover_host_iface)"
if [[ -z "$host_iface" ]]; then
  echo "ERROR: Unable to detect default host interface. Set HOST_IFACE and retry."
  exit 1
fi

iptables_bin="$(iptables_cmd)"
if [[ -z "$iptables_bin" ]]; then
  echo "ERROR: Missing iptables-nft/iptables binary."
  exit 1
fi

ensure_iptables_rule() {
  local table="$1"
  local chain="$2"
  shift 2
  local -a rule=("$@")
  local -a check_cmd=("$iptables_bin")
  local -a add_cmd=("$iptables_bin")

  if [[ -n "$table" ]]; then
    check_cmd+=(-t "$table")
    add_cmd+=(-t "$table")
  fi

  check_cmd+=(-C "$chain" "${rule[@]}")
  add_cmd+=(-A "$chain" "${rule[@]}")

  if run_as_root "${check_cmd[@]}" >/dev/null 2>&1; then
    return
  fi

  run_as_root "${add_cmd[@]}"
}

echo "Configuring host networking for Firecracker..."
echo "  TAP device: $TAP_DEV"
echo "  TAP IP:     $TAP_IP/$TAP_CIDR"
echo "  Guest IP:   $GUEST_IP/$TAP_CIDR"
echo "  Host iface: $host_iface"

if ip link show dev "$TAP_DEV" >/dev/null 2>&1; then
  echo "Reusing existing TAP device: $TAP_DEV"
else
  run_as_root ip tuntap add dev "$TAP_DEV" mode tap
fi

run_as_root ip addr replace "${TAP_IP}/${TAP_CIDR}" dev "$TAP_DEV"
run_as_root ip link set dev "$TAP_DEV" up
run_as_root sysctl -w net.ipv4.ip_forward=1 >/dev/null

ensure_iptables_rule "nat" "POSTROUTING" -o "$host_iface" -s "$GUEST_IP" -j MASQUERADE
ensure_iptables_rule "" "FORWARD" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ensure_iptables_rule "" "FORWARD" -i "$TAP_DEV" -o "$host_iface" -j ACCEPT

echo "Host networking ready."
echo "Guest network configuration is injected via kernel boot args."
echo "Guest DNS is also included via boot args (${GUEST_DNS_1}${GUEST_DNS_2:+, ${GUEST_DNS_2}})."
