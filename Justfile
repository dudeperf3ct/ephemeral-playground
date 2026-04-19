set shell := ["bash", "-euo", "pipefail", "-c"]
scripts_dir := justfile_directory() + "/scripts"
firecracker_bin := justfile_directory() + "/firecracker"
api_socket := "/tmp/firecracker.socket"

default:
    @just --list

help:
    @echo "Guided flow:"
    @echo "  1) Host check:   just check-kvm"
    @echo "  2) Assets check: just check-artifacts"
    @echo "  3) Start API:    just start-firecracker"
    @echo "  4) Configure VM: just configure-vm"
    @echo "  5) Boot VM:      just start-instance"
    @echo "  6) Inspect:      just status"
    @echo "  7) Stop/cleanup: just stop-firecracker"
    @echo "  8) Deep clean:   just clean"
    @echo ""
    @echo "Snapshot flow:"
    @echo "  Create:          just snapshot-create latest Full"
    @echo "  Restore (fresh): just snapshot-restore latest true"
    @echo "  Restore paused:  just snapshot-restore latest false"
    @echo "  Resume VM:       just vm-resume"
    @echo ""
    @echo "One-shot boot:"
    @echo "  just vm-up"
    @echo ""
    @echo "Interactive console flow (two terminals):"
    @echo "  Terminal A: just start-firecracker-console"
    @echo "  Terminal B: just boot-vm"

check-kvm:
    {{scripts_dir}}/check_kvm.sh

check-artifacts:
    {{scripts_dir}}/check_artifacts.sh

firecracker-install version="v1.8.0":
    {{scripts_dir}}/firecracker_install.sh "{{version}}"

start-firecracker: check-artifacts
    {{scripts_dir}}/start_firecracker.sh

start-firecracker-console: check-artifacts
    @echo "Starting Firecracker in foreground on {{api_socket}}..."
    @echo "Use a second terminal to run: just boot-vm"
    {{firecracker_bin}} --api-sock {{api_socket}}

configure-vm:
    {{scripts_dir}}/configure_vm.sh

start-instance:
    {{scripts_dir}}/start_instance.sh

snapshot-create name="latest" snapshot_type="Full":
    {{scripts_dir}}/snapshot_create.sh "{{name}}" "{{snapshot_type}}"

snapshot-restore name="latest" resume_vm="true": check-artifacts stop-firecracker start-firecracker
    {{scripts_dir}}/snapshot_restore.sh "{{name}}" "{{resume_vm}}"

vm-resume:
    {{scripts_dir}}/vm_state.sh Resumed

vm-pause:
    {{scripts_dir}}/vm_state.sh Paused

boot-vm: configure-vm start-instance
    @echo "MicroVM configured and started."

vm-up: check-kvm check-artifacts start-firecracker configure-vm start-instance
    @echo "Firecracker VM is up."

status:
    {{scripts_dir}}/status.sh

stop-firecracker:
    {{scripts_dir}}/stop_firecracker.sh

clean:
    {{scripts_dir}}/clean.sh
