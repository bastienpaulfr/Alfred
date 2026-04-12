#!/bin/zsh

# Ensure ADB is installed
if ! command -v adb &> /dev/null; then
    echo "ADB is not installed. Please install it first."
    exit 1
fi

# Initialize verbose flag
VERBOSE=false

# Initialize month parameter
MONTH_PARAM=""

WHATSAPP=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true ;;
        -w|--whatsapp) WHATSAPP=true ;;
        -h|--help)
            echo "Usage: $0 [-v|--verbose] [MONTH]"
            echo "       MONTH is optional and must be a number between 01 and 12."
            exit 0
            ;;
        *) MONTH_PARAM=$1 ;;
    esac
    shift
done

# Validate the month number if provided
if [[ -n "$MONTH_PARAM" && ( "$MONTH_PARAM" -lt 1 || "$MONTH_PARAM" -gt 12 ) ]]; then
    echo "Invalid month number. Please provide a valid month number (1-12) or leave it empty."
    exit 1
fi

# Convert MONTH_PARAM to two-digit format if necessary
if [[ -n "$MONTH_PARAM" ]]; then
    printf -v MONTH_PARAM "%02d" $MONTH_PARAM
fi

# Create a base directory to store the images
BASE_DIR="$HOME/Pictures"
mkdir -p "$BASE_DIR"

# Start the ADB server
$VERBOSE && echo "Starting ADB server..."
adb start-server
$VERBOSE && echo "Waiting for the Android device..."

# Wait for the device
adb wait-for-device

# Function to pull images from the device and organize them
pull_images() {
    local dest_subfolder=$1
    shift
    local files=("$@")
    $VERBOSE && echo "Pulling images from device..."

    for FILE in "${files[@]}"; do
        # Get the last modified time of the file from the device
        MOD_TIME=$(adb shell stat -c %Y "$FILE")

        LC_TIME=fr_FR.UTF-8
        YEAR=$(LC_TIME=$LC_TIME date -r $MOD_TIME +%Y)
        MONTH=$(LC_TIME=$LC_TIME date -r $MOD_TIME +%m)

        # If a month parameter is specified, skip files not from that month
        if [[ -n "$MONTH_PARAM" && "$MONTH" != "$MONTH_PARAM" ]]; then
            continue
        fi

        MONTH_NAME=$(LC_TIME=$LC_TIME date -r $MOD_TIME +%B)
        MONTH_NAME=$(echo "$MONTH_NAME" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
        FOLDER_NAME="$YEAR/$MONTH $MONTH_NAME"

        # Create a directory for the month if it doesn't exist
        DEST_DIR="$BASE_DIR/$FOLDER_NAME"
        if [[ -n "$dest_subfolder" ]]; then
            DEST_DIR="$DEST_DIR/$dest_subfolder"
        fi
        mkdir -p "$DEST_DIR"

        FILE=$(echo $FILE | sed 's/\\ / /g')
        $VERBOSE && echo "Pulling $FILE to $DEST_DIR/"
        # Pull the file to the appropriate directory
        adb pull "$FILE" "$DEST_DIR/"
    done
}


# Call the function to execute the image pulling and organizing
FILES=($(adb shell find /sdcard/DCIM/Camera -type f ! -name ".trashed*"))
pull_images "./" "${FILES[@]}"


$WHATSAPP && IFS=$'\n' FILES=($(adb shell find "/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp\ Images/Private" -type f ! -name ".trashed*" | sed 's/ /\\ /g'))
$WHATSAPP && pull_images "Whatsapp Bibiane" "${FILES[@]}"

$WHATSAPP && IFS=$'\n' FILES=($(adb shell find "/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp\ Video/Private" -type f ! -name ".trashed*" |  sed 's/ /\\ /g'))
$WHATSAPP && pull_images "Whatsapp Bibiane" "${FILES[@]}"


echo "All images have been transferred and organized by month."
