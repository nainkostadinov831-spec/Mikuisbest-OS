#!/usr/bin/env bash
set -euo pipefail

DEBIAN_RELEASE="trixie"
TARGET_ARCH="amd64"
PROJECT_ROOT="$(pwd)"
CONFIG_SRC="${PROJECT_ROOT}/config-src"

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die()  { log "ERROR: $*"; exit 1; }

command -v lb >/dev/null 2>&1 || die "'lb' not found. Run scripts/00-prepare-host.sh first."
[ -d "$CONFIG_SRC" ] || die "config-src/ not found. Run this from the project root."

log "Initializing live-build config for Debian $DEBIAN_RELEASE / $TARGET_ARCH..."

lb config \
    --mode debian \
    --distribution "$DEBIAN_RELEASE" \
    --architectures "$TARGET_ARCH" \
    --archive-areas "main contrib non-free-firmware" \
    --mirror-bootstrap "http://deb.debian.org/debian/" \
    --mirror-chroot "http://deb.debian.org/debian/" \
    --mirror-binary "http://deb.debian.org/debian/" \
    --security false \
    --firmware-chroot false \
    --firmware-binary false \
    --binary-images iso-hybrid \
    --iso-application "Mikoisbest OS" \
    --iso-publisher "Mikoisbest OS Project" \
    --iso-volume "MIKOISBEST_V1" \
    --apt-recommends false \
    --linux-packages "linux-image" \
    --linux-flavours "amd64" \
    --initramfs "live-boot" \
    --initsystem "systemd" \
    || die "lb config failed"

[ -d "${PROJECT_ROOT}/config" ] || die "lb config did not produce a config/ directory."

log "Copying package list into config/package-lists/..."
mkdir -p "${PROJECT_ROOT}/config/package-lists"
cp "${CONFIG_SRC}/package-lists/mikoisbest.list.chroot" \
   "${PROJECT_ROOT}/config/package-lists/mikoisbest.list.chroot"

log "Copying hooks into config/hooks/live/..."
mkdir -p "${PROJECT_ROOT}/config/hooks/live"
cp "${CONFIG_SRC}/hooks/live/"*.hook.chroot \
   "${PROJECT_ROOT}/config/hooks/live/"
chmod +x "${PROJECT_ROOT}/config/hooks/live/"*.hook.chroot

log "Copying APT pin files into config/archives/..."
mkdir -p "${PROJECT_ROOT}/config/archives"
cp "${CONFIG_SRC}/archives/"*.pref.chroot \
   "${PROJECT_ROOT}/config/archives/"

log "Verifying required dependency: mikoisbest.list.chroot is not empty..."
[ -s "${PROJECT_ROOT}/config/package-lists/mikoisbest.list.chroot" ] || \
    die "Package list is empty — refusing to proceed with an empty ISO."

log "Config initialized. Review config/package-lists and config/hooks/live before building."
log "Next: sudo bash build.sh"
