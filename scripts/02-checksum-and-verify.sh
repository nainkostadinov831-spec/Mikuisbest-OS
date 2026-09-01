#!/usr/bin/env bash
#
# 02-checksum-and-verify.sh — Generate and verify the SHA-256 checksum of
# the built ISO. Usage: bash scripts/02-checksum-and-verify.sh Mikoisbest_OS_v1.iso

set -euo pipefail

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die()  { log "ERROR: $*"; exit 1; }

ISO_PATH="${1:-}"
[ -n "$ISO_PATH" ] || die "Usage: $0 <path-to-iso>"
[ -f "$ISO_PATH" ] || die "File not found: $ISO_PATH"
[ -s "$ISO_PATH" ] || die "ISO file is empty: $ISO_PATH"

# Sanity-check it's actually an ISO-ish file, not a stray empty artifact
FILE_TYPE="$(file -b "$ISO_PATH")"
log "file(1) reports: $FILE_TYPE"
case "$FILE_TYPE" in
    *ISO\ 9660*|*DOS/MBR\ boot\ sector*) ;;
    *) log "WARNING: file type doesn't look like a typical hybrid ISO. Inspect manually before trusting it." ;;
esac

SUM_FILE="${ISO_PATH}.sha256"
log "Generating SHA-256 checksum..."
sha256sum "$ISO_PATH" | tee "$SUM_FILE"

log "Verifying checksum..."
sha256sum -c "$SUM_FILE" || die "Checksum verification FAILED — the ISO is corrupted or was modified."

log "Checksum OK: $SUM_FILE"
