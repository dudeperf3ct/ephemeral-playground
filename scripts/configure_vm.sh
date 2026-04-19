#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

require_api_socket

echo "Configuring machine..."
firecracker_put "machine-config" '{
  "vcpu_count": 1,
  "mem_size_mib": 256,
  "smt": false
}'

echo "Configuring boot source..."
firecracker_put "boot-source" "{
  \"kernel_image_path\": \"$KERNEL\",
  \"boot_args\": \"$BOOT_ARGS\"
}"

echo "Configuring rootfs..."
firecracker_put "drives/rootfs" "{
  \"drive_id\": \"rootfs\",
  \"path_on_host\": \"$ROOTFS\",
  \"is_root_device\": true,
  \"is_read_only\": false
}"

sleep 0.05
echo "VM configuration applied."
