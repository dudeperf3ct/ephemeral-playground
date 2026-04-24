#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

NET_REMOVE_CONNTRACK_RULE="${NET_REMOVE_CONNTRACK_RULE:-false}"
NET_DISABLE_IP_FORWARD="${NET_DISABLE_IP_FORWARD:-false}"

host_iface="$(discover_host_iface)"
iptables_bin="$(iptables_cmd)"

delete_iptables_rule_if_present() {
  local table="$1"
  local chain="$2"
  shift 2
  local -a rule=("$@")
  local -a check_cmd=("$iptables_bin")
  local -a delete_cmd=("$iptables_bin")

  if [[ -n "$table" ]]; then
    check_cmd+=(-t "$table")
    delete_cmd+=(-t "$table")
  fi

  check_cmd+=(-C "$chain" "${rule[@]}")
  delete_cmd+=(-D "$chain" "${rule[@]}")

  if run_as_root "${check_cmd[@]}" >/dev/null 2>&1; then
    run_as_root "${delete_cmd[@]}"
  fi
}

echo "Cleaning up Firecracker host networking..."

if [[ -n "$host_iface" && -n "$iptables_bin" ]]; then
  delete_iptables_rule_if_present "nat" "POSTROUTING" -o "$host_iface" -s "$GUEST_IP" -j MASQUERADE
  delete_iptables_rule_if_present "" "FORWARD" -i "$TAP_DEV" -o "$host_iface" -j ACCEPT
  if [[ "$NET_REMOVE_CONNTRACK_RULE" == "true" ]]; then
    delete_iptables_rule_if_present "" "FORWARD" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  fi
else
  echo "Skipping iptables cleanup (missing host iface or iptables binary)."
fi

if command -v ip >/dev/null 2>&1 && ip link show dev "$TAP_DEV" >/dev/null 2>&1; then
  run_as_root ip link del "$TAP_DEV"
  echo "Removed TAP device: $TAP_DEV"
else
  echo "No TAP device found: $TAP_DEV"
fi

if [[ "$NET_DISABLE_IP_FORWARD" == "true" ]]; then
  run_as_root sysctl -w net.ipv4.ip_forward=0 >/dev/null
  echo "Disabled IPv4 forwarding."
fi

echo "Host networking cleanup complete."
