#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

state="${1:-}"
case "$state" in
  Resumed|Paused) ;;
  *)
    echo "ERROR: state must be 'Resumed' or 'Paused'"
    exit 1
    ;;
esac

require_api_socket
firecracker_patch "vm" "{\"state\":\"$state\"}"
echo "VM state set to: $state"
