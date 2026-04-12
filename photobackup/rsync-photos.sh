#!/usr/bin/env bash
set -euo pipefail

# rsync-photos.sh — Sync year folders from ~/Pictures to external volume
# Usage: rsync-photos.sh [-n] [-v]
#   -n  Dry run — show what would be transferred
#   -v  Verbose output
#   -h  Show this help

SRC="$HOME/Pictures"
DEST="/Volumes/Photos/Photos"

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
RSYNC_OPTS=(-a --delete --progress --exclude='.DS_Store' --exclude='Thumbs.db' --exclude='._*')
$DRY_RUN && RSYNC_OPTS+=(--dry-run)
$VERBOSE && RSYNC_OPTS+=(-v)

# Sync each subfolder within each year folder individually.
# This ensures destination-only folders (e.g. "Baptème de Clément") are never
# deleted — only the content of matching subfolders is mirrored.
synced=0
for year_dir in "$SRC"/[0-9][0-9][0-9][0-9]; do
    [[ -d "$year_dir" ]] || continue
    year=$(basename "$year_dir")

    for sub_dir in "$year_dir"/*/; do
        [[ -d "$sub_dir" ]] || continue
        sub=$(basename "$sub_dir")
        dest_sub="$DEST/$year/$sub"
        mkdir -p "$dest_sub"
        echo "Syncing $year/$sub..."
        rsync "${RSYNC_OPTS[@]}" "$sub_dir" "$dest_sub/"
        ((++synced))
    done
done

if [[ $synced -eq 0 ]]; then
    echo "No year folders found in $SRC."
else
    echo "Done. Synced $synced folder(s)."
fi
