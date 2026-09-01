#!/usr/bin/env bash
#
# 03-test-qemu.sh — Boot the built ISO in QEMU for non-destructive testing.
# Usage:
#   bash scripts/03-test-qemu.sh Mikoisbest_OS_v1.iso        # BIOS boot
#   bash scripts/03-test-qemu.sh -u Mikoisbest_OS_v1.iso     # UEFI boot (needs ovmf)

set -euo pipefail

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die()  { log "ERROR: $*"; exit 1; }

UEFI=0
if [ "${1:-}" = "-u" ]; then
    UEFI=1
    shift
fi

ISO_PATH="${1:-}"
[ -n "$ISO_PATH" ] || die "Usage: $0 [-u] <path-to-iso>"
[ -f "$ISO_PATH" ] || die "File not found: $ISO_PATH"

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "qemu-system-x86_64 not found. Install with: sudo apt install qemu-system-x86"

KVM_ARGS=()
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_ARGS=(-enable-kvm -cpu host)
    log "KVM acceleration available — using it."
else
    log "KVM not available/usable — falling back to slower software emulation."
fi

COMMON_ARGS=(
    -m 2048
    -smp 2
    -cdrom "$ISO_PATH"
    -boot d
    -vga std
    -netdev user,id=net0
    -device e1000,netdev=net0
)

if [ "$UEFI" -eq 1 ]; then
    OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
    [ -f "$OVMF_CODE" ] || die "OVMF firmware not found at $OVMF_CODE. Install with: sudo apt install ovmf"
    log "Booting $ISO_PATH in QEMU (UEFI mode)..."
    qemu-system-x86_64 "${KVM_ARGS[@]}" "${COMMON_ARGS[@]}" -bios "$OVMF_CODE"
else
    log "Booting $ISO_PATH in QEMU (BIOS/legacy mode)..."
    qemu-system-x86_64 "${KVM_ARGS[@]}" "${COMMON_ARGS[@]}"
fi
