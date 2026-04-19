#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

version="${1:-v1.8.0}"
arch="$(uname -m)"
case "$arch" in
  x86_64|aarch64) ;;
  arm64) arch="aarch64" ;;
  *)
    echo "ERROR: Unsupported architecture: $arch"
    exit 1
    ;;
esac

url="https://github.com/firecracker-microvm/firecracker/releases/download/${version}/firecracker-${version}-${arch}.tgz"
tgz="/tmp/firecracker-${version}-${arch}.tgz"
extract_dir="/tmp/firecracker-${version}-${arch}"

echo "Downloading: $url"
curl -fL "$url" -o "$tgz"

rm -rf "$extract_dir"
mkdir -p "$extract_dir"
tar -xzf "$tgz" -C "$extract_dir"

binary_path="$(find "$extract_dir" -type f -name 'firecracker-*' | head -n 1)"
if [[ -z "$binary_path" ]]; then
  echo "ERROR: Could not find firecracker binary in downloaded archive."
  exit 1
fi

cp "$binary_path" "$FIRECRACKER_BIN"
chmod +x "$FIRECRACKER_BIN"
echo "Installed Firecracker: $FIRECRACKER_BIN"
