#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

name="${1:-latest}"
snapshot_type="${2:-Full}"
case "$snapshot_type" in
  Full|Diff) ;;
  *)
    echo "ERROR: snapshot type must be 'Full' or 'Diff' (got: $snapshot_type)"
    exit 1
    ;;
esac

require_api_socket
mkdir -p "$SNAPSHOT_DIR"

snapshot_path="$SNAPSHOT_DIR/${name}.vmstate"
mem_path="$SNAPSHOT_DIR/${name}.mem"
metadata_path="$SNAPSHOT_DIR/${name}.meta"

paused=0
resume_if_needed() {
  if [[ "$paused" -eq 1 ]]; then
    firecracker_patch "vm" '{"state":"Resumed"}' || true
  fi
}
trap resume_if_needed EXIT

echo "Pausing VM..."
firecracker_patch "vm" '{"state":"Paused"}'
paused=1

echo "Creating $snapshot_type snapshot..."
firecracker_put "snapshot/create" "{
  \"snapshot_type\": \"$snapshot_type\",
  \"snapshot_path\": \"$snapshot_path\",
  \"mem_file_path\": \"$mem_path\"
}"

printf '%s\n' \
  "name=$name" \
  "snapshot_type=$snapshot_type" \
  "snapshot_path=$snapshot_path" \
  "mem_file_path=$mem_path" \
  "created_at=$(date -Iseconds)" >"$metadata_path"

echo "Resuming VM..."
firecracker_patch "vm" '{"state":"Resumed"}'
paused=0

echo "Snapshot created:"
echo "  state: $snapshot_path"
echo "  memory: $mem_path"
echo "  meta: $metadata_path"
