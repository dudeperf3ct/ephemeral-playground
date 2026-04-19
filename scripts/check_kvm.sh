#!/usr/bin/env bash
set -euo pipefail

if [[ ! -e /dev/kvm ]]; then
  echo "ERROR: /dev/kvm is missing. Enable virtualization and KVM kernel modules."
  exit 1
fi

ls -l /dev/kvm

if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  echo "OK: /dev/kvm is readable and writable for $(id -un)."
else
  echo "WARN: /dev/kvm exists but this user may not have full access."
  echo "Try: sudo usermod -aG kvm \"$USER\" && newgrp kvm"
fi
