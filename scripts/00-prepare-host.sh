#!/usr/bin/env bash
#
# 00-prepare-host.sh — Prepares a clean Debian 13 (trixie) machine to build
# Mikoisbest OS. Installs live-build and required dependencies.
# Run as root: sudo bash scripts/00-prepare-host.sh

set -euo pipefail

DEBIAN_RELEASE="trixie"
REQUIRED_PACKAGES=(
    live-build
    live-config
    live-boot
    debootstrap
    xorriso
    isolinux
    syslinux-efi
    grub-pc-bin
    grub-efi-amd64-bin
    grub-efi-amd64-signed
    mtools
    dosfstools
    squashfs-tools
    qemu-system-x86
    ovmf
    ca-certificates
    gnupg
)

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die()  { log "ERROR: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Must be run as root: sudo bash $0"

# Release check — warn, don't silently continue on a mismatched host.
# In CI (no TTY, e.g. GitHub Actions ubuntu-latest) we can't prompt, so we
# log a loud warning and proceed instead of hanging forever on `read`.
if ! grep -qi "$DEBIAN_RELEASE" /etc/os-release 2>/dev/null; then
    log "WARNING: this host does not report itself as Debian '$DEBIAN_RELEASE'."
    log "Current /etc/os-release:"
    cat /etc/os-release
    if [ -t 0 ]; then
        read -r -p "Continue anyway? [y/N] " REPLY
        [[ "$REPLY" =~ ^[Yy]$ ]] || die "Aborted by user."
    else
        log "No TTY detected (CI environment) — continuing automatically. live-build itself still targets Debian $DEBIAN_RELEASE regardless of the host OS."
    fi
fi

ARCH="$(dpkg --print-architecture)"
log "Detected architecture: $ARCH"
[ "$ARCH" = "amd64" ] || log "WARNING: this spec targets amd64; other architectures are unverified."

log "Updating package index..."
apt-get update

log "Installing build dependencies: ${REQUIRED_PACKAGES[*]}"
if ! apt-get install -y "${REQUIRED_PACKAGES[@]}"; then
    die "One or more build dependencies failed to install. Check package names against https://packages.debian.org/$DEBIAN_RELEASE/ and re-run."
fi

# Verify the critical binary is actually present and runnable
command -v lb >/dev/null 2>&1 || die "live-build installed but 'lb' command not found in PATH."
log "live-build version: $(lb --version 2>&1 | head -1)"

log "Host preparation complete."
