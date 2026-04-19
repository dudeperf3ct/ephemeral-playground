#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

for file in "$FIRECRACKER_BIN" "$KERNEL" "$ROOTFS"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: Missing required file: $file"
    exit 1
  fi
done

if [[ ! -x "$FIRECRACKER_BIN" ]]; then
  chmod +x "$FIRECRACKER_BIN"
fi

ls -lh "$FIRECRACKER_BIN" "$KERNEL" "$ROOTFS"
echo "Artifacts look good."
