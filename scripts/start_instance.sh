#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

require_api_socket

echo "Starting microVM..."
firecracker_put "actions" '{"action_type":"InstanceStart"}'
echo "MicroVM started."
