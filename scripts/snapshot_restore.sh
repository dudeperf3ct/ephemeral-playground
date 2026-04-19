#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

name="${1:-latest}"
resume_vm="${2:-true}"

if [[ "$resume_vm" != "true" && "$resume_vm" != "false" ]]; then
  echo "ERROR: resume_vm must be 'true' or 'false' (got: $resume_vm)"
  exit 1
fi

snapshot_path="$SNAPSHOT_DIR/${name}.vmstate"
mem_path="$SNAPSHOT_DIR/${name}.mem"

if [[ ! -f "$snapshot_path" ]]; then
  echo "ERROR: Missing snapshot state file: $snapshot_path"
  exit 1
fi

if [[ ! -f "$mem_path" ]]; then
  echo "ERROR: Missing snapshot memory file: $mem_path"
  exit 1
fi

require_api_socket

echo "Loading snapshot '$name'..."
firecracker_put "snapshot/load" "{
  \"snapshot_path\": \"$snapshot_path\",
  \"mem_file_path\": \"$mem_path\",
  \"enable_diff_snapshots\": false,
  \"resume_vm\": $resume_vm
}"

echo "Snapshot restored."
echo "  state: $snapshot_path"
echo "  memory: $mem_path"
echo "  resume_vm: $resume_vm"
