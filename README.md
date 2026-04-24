# Ephemeral playground

Firecracker microVM playground driven by `just` tasks with script-backed implementation.

Use `just help` for guided detached and interactive console flows.

## Prerequisites

- Linux host with KVM (`/dev/kvm` present and accessible)
- `bash`, `curl`, `tar`
- `ip` (`iproute2`) and `iptables`/`iptables-nft`
- `sudo` access (or run as root) for TAP/NAT setup
- `just` (optional but recommended)
- Local artifacts:
  - `firecracker`: Firecracker binary
  - `artifacts/vmlinux.bin`: Guest kernel image
  - `artifacts/rootfs.ext4`: Guest root filesystem

## Install/Update Firecracker Binary

This installs `firecracker` binary into the project root.

```bash
just firecracker-install
# or pin a version
just firecracker-install v1.15.1
```

## Interactive VM Shell (serial console)

Detached mode (`just vm-up`) writes guest console output to `artifacts/firecracker.log`.
For an interactive shell, use foreground console mode with two terminals:

Terminal A:

```bash
just start-firecracker-console
```

Terminal B:

```bash
just boot-vm
```

Then return to Terminal A and interact at the guest prompt.

Stop and clean up:

```bash
just stop-firecracker
```

Remove log files, socket file or any temporary files created:

```bash
just clean
```

## Individual steps

```bash
just check-kvm
just check-artifacts
just start-firecracker
just network-up
just configure-vm
just start-instance
just status
```

Or run everything in one shot:

```bash
just vm-up
```

This start microVM in a detached state without any access to the guest OS console.

`vm-up` also includes host networking (`network-up`) and guest IPv4 config via kernel boot args.

Stop and clean up:

```bash
just stop-firecracker
```

Remove log files, socket file or any temporary files created:

```bash
just clean
```

`just clean` stops Firecracker (if running) and removes API socket, pid/log files, metrics files, snapshot artifacts, and `/tmp/firecracker-v*` install temp files.

## Snapshots

Create a snapshot from a running VM (pauses VM, saves state+memory, resumes VM):

```bash
just snapshot-create latest Full
```

This writes files to `artifacts/snapshots/`:
- `latest.vmstate`
- `latest.mem`
- `latest.meta`

Restore snapshot into a fresh Firecracker process:

```bash
just snapshot-restore latest true
```

If you restore with `false`, the VM stays paused:

```bash
just snapshot-restore latest false
just vm-resume
```

## Logs

Follow guest serial output in detached mode:

```bash
tail -f artifacts/firecracker.log
```

## Expected Output

- `just check-kvm`: shows `/dev/kvm` permissions and `OK` for user access.
- `just check-artifacts`: lists `firecracker`, `vmlinux.bin`, `rootfs.ext4`, then `Artifacts look good.`
- `just start-firecracker`: prints PID, socket path (`/tmp/firecracker.socket`), and log path.
- `just configure-vm`: prints machine/boot/rootfs configuration steps and `VM configuration applied.`
- `just network-up`: creates TAP (`tap0`), enables host forwarding, and configures NAT.
- `just start-instance`: prints `MicroVM started.`
- `just status`: shows process/socket status and recent `artifacts/firecracker.log` lines.
- `just clean`: removes host-side temp/log/metrics/snapshot artifacts and tears down host networking.
- `just start-firecracker-console` + `just boot-vm`: gives an interactive serial shell in Terminal A.

## Networking

By default the project sets up:
- Host TAP: `tap0` at `172.16.0.1/30`
- Guest IP: `172.16.0.2/30` (injected via `boot_args` as `ip=...`)
- Guest DNS: `8.8.8.8`, `1.1.1.1` (injected via `boot_args`)
- NAT/forwarding from guest traffic to the host default interface

Bring networking up/down explicitly:

```bash
just network-up
just network-down
```

Useful overrides:
- `TAP_DEV` (default `tap0`)
- `TAP_IP` (default `172.16.0.1`)
- `GUEST_IP` (default `172.16.0.2`)
- `TAP_CIDR` (default `30`)
- `GUEST_IFACE` (default `eth0`)
- `GUEST_DNS_1` (default `8.8.8.8`)
- `GUEST_DNS_2` (default `1.1.1.1`)
- `HOST_IFACE` (auto-detected if unset)

Disable DNS injection by setting both empty, e.g. `GUEST_DNS_1= GUEST_DNS_2= just vm-up`.
