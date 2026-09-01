#!/usr/bin/env bash
set -euo pipefail

DISTRO_NAME="Mikoisbest OS"
DISTRO_VERSION="v1"
DEBIAN_RELEASE="trixie"
TARGET_ARCH="amd64"
BUILD_DIR="$(pwd)"
FINAL_ISO_NAME="Mikoisbest_OS_v1.iso"
LOG_FILE="${BUILD_DIR}/build-$(date +%Y%m%d-%H%M%S).log"

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
die()  { log "ERROR: $*"; exit 1; }

trap 'die "build.sh aborted (line $LINENO). See $LOG_FILE"' ERR

[ "$(id -u)" -eq 0 ] || die "Must be run as root: sudo bash build.sh (or run inside a root container)"

command -v lb >/dev/null 2>&1 || die "live-build ('lb') not found. Run scripts/00-prepare-host.sh first."

CURRENT_ARCH="$(dpkg --print-architecture)"
[ "$CURRENT_ARCH" = "$TARGET_ARCH" ] || \
    die "Build host arch ($CURRENT_ARCH) != target arch ($TARGET_ARCH)."

[ -f "${BUILD_DIR}/scripts/01-init-config.sh" ] || die "scripts/01-init-config.sh not found."

DISK_AVAIL_KB="$(df --output=avail "$BUILD_DIR" | tail -1)"
[ "$DISK_AVAIL_KB" -gt 8000000 ] || \
    log "WARNING: less than ~8GB free in $BUILD_DIR. Build may fail from lack of disk space."

log "Pre-flight checks passed."
log "$DISTRO_NAME $DISTRO_VERSION — Debian $DEBIAN_RELEASE — arch $TARGET_ARCH"
log "live-build version: $(lb --version 2>&1 | head -1)"

# Clean any previous partial build state, then IMMEDIATELY re-run lb config.
# Some live-build versions clear the "config" stage marker on `lb clean --purge`,
# which then makes `lb build` refuse to run ("stage required first: config").
# Re-running 01-init-config.sh right after clean guarantees the config stage
# is always freshly marked done immediately before the real build starts,
# regardless of what clean wiped.
log "Cleaning any previous build state..."
lb clean --purge 2>&1 | tee -a "$LOG_FILE" || log "lb clean reported non-fatal issues, continuing"

log "Re-initializing live-build config after clean..."
bash "${BUILD_DIR}/scripts/01-init-config.sh" 2>&1 | tee -a "$LOG_FILE" || die "re-init of config failed"

log "Starting lb build (this will take a while)..."
if ! lb build 2>&1 | tee -a "$LOG_FILE"; then
    die "lb build failed. Check $LOG_FILE for the first 'E:' error, and see README.md section H (Troubleshooting)."
fi

PRODUCED_ISO="$(find "$BUILD_DIR" -maxdepth 1 -name 'live-image-*.iso' -print -quit)"
[ -n "$PRODUCED_ISO" ] && [ -f "$PRODUCED_ISO" ] || \
    die "lb build reported success but no ISO was found."

log "Build produced: $PRODUCED_ISO"
mv -f "$PRODUCED_ISO" "$BUILD_DIR/$FINAL_ISO_NAME"
log "Renamed to $FINAL_ISO_NAME"

sha256sum "$BUILD_DIR/$FINAL_ISO_NAME" | tee "$BUILD_DIR/${FINAL_ISO_NAME}.sha256" | tee -a "$LOG_FILE"

log "Build complete: $BUILD_DIR/$FINAL_ISO_NAME"
exit 0
