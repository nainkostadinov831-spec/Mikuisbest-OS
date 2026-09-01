#!/usr/bin/env bash
#
# build.sh — Mikoisbest OS v1 top-level build orchestrator.
# Must be run as root (live-build's `lb build` requires root to chroot/mount).
# Run scripts/00-prepare-host.sh and scripts/01-init-config.sh first.

set -euo pipefail

# ---- Configuration variables ----------------------------------------------
DISTRO_NAME="Mikoisbest OS"
DISTRO_VERSION="v1"
DEBIAN_RELEASE="trixie"
TARGET_ARCH="amd64"
BUILD_DIR="$(pwd)"
FINAL_ISO_NAME="Mikoisbest_OS_v1.iso"
LOG_FILE="${BUILD_DIR}/build-$(date +%Y%m%d-%H%M%S).log"

# ---- Helpers ----------------------------------------------------------------
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
die()  { log "ERROR: $*"; exit 1; }

trap 'die "build.sh aborted (line $LINENO). See $LOG_FILE"' ERR

# ---- Pre-flight checks -------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "Must be run as root: sudo bash build.sh"

command -v lb >/dev/null 2>&1 || die "live-build ('lb') not found. Run scripts/00-prepare-host.sh first."

CURRENT_ARCH="$(dpkg --print-architecture)"
[ "$CURRENT_ARCH" = "$TARGET_ARCH" ] || \
    die "Build host arch ($CURRENT_ARCH) != target arch ($TARGET_ARCH). Cross-arch builds aren't covered by this spec."

if ! grep -qi "$DEBIAN_RELEASE" /etc/os-release 2>/dev/null; then
    log "WARNING: /etc/os-release does not mention '$DEBIAN_RELEASE'. Building on a mismatched host is unsupported."
    log "         Continuing anyway, but verify this is intentional."
fi

[ -d "${BUILD_DIR}/config" ] || die "No config/ directory found. Run scripts/01-init-config.sh first."
[ -f "${BUILD_DIR}/config/package-lists/mikoisbest.list.chroot" ] || \
    die "Package list missing from config/package-lists/. Run scripts/01-init-config.sh first."

DISK_AVAIL_KB="$(df --output=avail "$BUILD_DIR" | tail -1)"
[ "$DISK_AVAIL_KB" -gt 15000000 ] || \
    die "Less than ~15GB free in $BUILD_DIR. live-build needs substantial scratch space; free up disk first."

log "Pre-flight checks passed."
log "$DISTRO_NAME $DISTRO_VERSION — Debian $DEBIAN_RELEASE — arch $TARGET_ARCH"
log "live-build version: $(lb --version 2>&1 | head -1)"

# ---- Clean any previous partial build ----------------------------------------
log "Cleaning any previous build state..."
lb clean --purge 2>&1 | tee -a "$LOG_FILE" || die "lb clean failed"

# ---- Build --------------------------------------------------------------------
log "Starting lb build (this will take a while)..."
if ! lb build 2>&1 | tee -a "$LOG_FILE"; then
    die "lb build failed. Check $LOG_FILE for the first 'E:' error, and see README.md section H (Troubleshooting)."
fi

# ---- Verify output --------------------------------------------------------------
PRODUCED_ISO="$(find "$BUILD_DIR" -maxdepth 1 -name 'live-image-*.iso' -print -quit)"
[ -n "$PRODUCED_ISO" ] && [ -f "$PRODUCED_ISO" ] || \
    die "lb build reported success but no ISO was found. Do not treat this as a valid image."

log "Build produced: $PRODUCED_ISO"
mv -f "$PRODUCED_ISO" "$BUILD_DIR/$FINAL_ISO_NAME"
log "Renamed to $FINAL_ISO_NAME"

sha256sum "$BUILD_DIR/$FINAL_ISO_NAME" | tee "$BUILD_DIR/${FINAL_ISO_NAME}.sha256" | tee -a "$LOG_FILE"

log "Build complete: $BUILD_DIR/$FINAL_ISO_NAME"
log "Next: bash scripts/03-test-qemu.sh $FINAL_ISO_NAME"
exit 0
