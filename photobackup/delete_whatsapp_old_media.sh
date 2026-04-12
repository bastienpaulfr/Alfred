#!/usr/bin/env bash
#set -euo pipefail

usage() {
    echo "Usage: $0 <keep-from-date>"
    echo "  keep-from-date: files created on or after this date are kept (format: YYYY-MM-DD)"
    echo ""
    echo "Example: $0 2024-01-01"
    echo "  => deletes all WhatsApp images/videos created before Jan 1, 2024"
    exit 1
}

# --- Args ---
[[ $# -ne 1 ]] && usage

KEEP_FROM="$1"

# Validate date format
if ! [[ "$KEEP_FROM" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: invalid date format '$KEEP_FROM'. Expected YYYY-MM-DD."
    exit 1
fi

# Convert to timestamp for comparison (YYYYMMDD)
KEEP_FROM_TS="${KEEP_FROM//-/}"

# --- ADB check ---
if ! command -v adb &>/dev/null; then
    echo "Error: adb not found in PATH."
    exit 1
fi

if ! adb devices | grep -q "device$"; then
    echo "Error: no device connected (or unauthorized)."
    exit 1
fi

# --- WhatsApp media directories ---
WHATSAPP_DIRS=(
    "/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Private"
    "/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/Private"
)

echo "Deleting WhatsApp media created before $KEEP_FROM ..."
echo ""

DELETED=0
ERRORS=0

for DIR in "${WHATSAPP_DIRS[@]}"; do
    # Check if directory exists on device
    if ! adb shell "[ -d '$DIR' ]" 2>/dev/null; then
        echo "[skip] $DIR (not found)"
        continue
    fi

    echo "[scan] $DIR"

    # Collect all filenames upfront to avoid adb stealing stdin in the loop
    FILES=()
    while IFS= read -r line; do
        FILES+=("$line")
    done < <(adb shell "ls '$DIR'" 2>/dev/null)

    # List files and extract date from filename (format: IMG-YYYYMMDD-WAnnnn.ext)
    for FILE_NAME in "${FILES[@]}"; do
        [[ -z "$FILE_NAME" ]] && continue

        if [[ "$FILE_NAME" =~ ^[A-Z]+-([0-9]{8})-WA[0-9]+\..+$ ]]; then
            FILE_DATE="${BASH_REMATCH[1]}"
        else
            continue
        fi

        if [[ "$FILE_DATE" -lt "$KEEP_FROM_TS" ]]; then
            FILE_PATH="$DIR/$FILE_NAME"
            if adb shell "rm '$FILE_PATH'" 2>/dev/null; then
                echo "  deleted: $FILE_NAME ($FILE_DATE)"
                (( DELETED++ )) || true
            else
                echo "  error:   $FILE_NAME"
                (( ERRORS++ )) || true
            fi
        fi
    done
done

echo ""
echo "Done. $DELETED file(s) deleted, $ERRORS error(s)."
