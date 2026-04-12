#!/usr/bin/env bash
set -euo pipefail

# rsync-photos.sh — Sync year folders from ~/Pictures to external volume
# Usage: rsync-photos.sh [-n] [-v]
#   -n  Dry run — show what would be transferred
#   -v  Verbose output
#   -h  Show this help

SRC="$HOME/Pictures"
DEST="/Volumes/Photo/Photo"

DRY_RUN=false
VERBOSE=false

usage() {
    sed -n '3,7s/^# \?//p' "${BASH_SOURCE[0]}"
    exit 0
}

while getopts "nvh" opt; do
    case "$opt" in
        n) DRY_RUN=true ;;
        v) VERBOSE=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check destination volume is mounted
if [[ ! -d "$DEST" ]]; then
    echo "Error: destination $DEST not found. Is the volume mounted?"
    exit 1
fi

# Build rsync flags
RSYNC_OPTS=(-a --progress)
$DRY_RUN && RSYNC_OPTS+=(--dry-run)
$VERBOSE && RSYNC_OPTS+=(-v)

# Sync each year folder
synced=0
for dir in "$SRC"/[0-9][0-9][0-9][0-9]; do
    [[ -d "$dir" ]] || continue
    name=$(basename "$dir")
    echo "Syncing $name..."
    rsync "${RSYNC_OPTS[@]}" "$dir/" "$DEST/$name/"
    ((synced++))
done

if [[ $synced -eq 0 ]]; then
    echo "No year folders found in $SRC."
else
    echo "Done. Synced $synced folder(s)."
fi
