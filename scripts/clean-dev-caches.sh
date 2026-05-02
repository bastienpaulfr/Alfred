#!/bin/bash
#
# clean-dev-caches.sh — Interactive disk cleanup for Android/iOS developers
#
# Usage:
#   clean-dev-caches.sh [OPTIONS] [SECTION...]
#
# Options:
#   -n, --dry-run    Show sizes without deleting
#   -y, --yes        Auto-confirm all prompts
#   -l, --list       List available sections
#   -h, --help       Show this help
#
# Sections (run only those listed; default: all):
#   xcode            Xcode DerivedData
#   gradle           Gradle caches / wrapper / daemon
#   google           Google caches (Android Studio / Chrome)
#   android-studio   Old Android Studio app-support versions
#   avd              Android emulators
#   ios-sim          iOS unavailable simulators
#   brew             Homebrew cache
#   maven            Maven local repository
#   cocoapods        CocoaPods cache
#   logs             ~/Library/Logs
#
# Examples:
#   clean-dev-caches.sh                    # all sections, interactive
#   clean-dev-caches.sh xcode gradle       # only Xcode and Gradle
#   clean-dev-caches.sh -n                 # dry run, all sections
#   clean-dev-caches.sh -y maven           # auto-confirm Maven only
#

set -euo pipefail

DRY_RUN=false
ASSUME_YES=false
SECTIONS=()

ALL_SECTIONS=(xcode gradle google android-studio avd ios-sim brew maven cocoapods logs)

usage() {
    sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'
}

list_sections() {
    cat <<EOF
Available sections:
  xcode            Xcode DerivedData
  gradle           Gradle caches / wrapper / daemon
  google           Google caches (Android Studio / Chrome)
  android-studio   Old Android Studio app-support versions
  avd              Android emulators
  ios-sim          iOS unavailable simulators
  brew             Homebrew cache
  maven            Maven local repository
  cocoapods        CocoaPods cache
  logs             ~/Library/Logs
EOF
}

is_valid_section() {
    local s="$1"
    for known in "${ALL_SECTIONS[@]}"; do
        [ "$s" = "$known" ] && return 0
    done
    return 1
}

# --- Parse CLI args ---

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=true ;;
        -y|--yes)     ASSUME_YES=true ;;
        -l|--list)    list_sections; exit 0 ;;
        -h|--help)    usage; exit 0 ;;
        --)           shift; while [ $# -gt 0 ]; do SECTIONS+=("$1"); shift; done; break ;;
        -*)
            printf "Unknown option: %s\n\n" "$1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if is_valid_section "$1"; then
                SECTIONS+=("$1")
            else
                printf "Unknown section: %s\n\n" "$1" >&2
                list_sections >&2
                exit 2
            fi
            ;;
    esac
    shift
done

# Default to all sections if none specified
if [ ${#SECTIONS[@]} -eq 0 ]; then
    SECTIONS=("${ALL_SECTIONS[@]}")
fi

run_section() {
    local s="$1"
    for picked in "${SECTIONS[@]}"; do
        [ "$picked" = "$s" ] && return 0
    done
    return 1
}

HOME_DIR="$HOME"

# Colors
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

total_freed=0

# --- Helpers ---

human_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=0; $bytes / 1048576" | bc) MB"
    else
        echo "$(echo "scale=0; $bytes / 1024" | bc) KB"
    fi
}

dir_size_bytes() {
    local path="$1"
    if [ -d "$path" ]; then
        du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}'
    else
        echo "0"
    fi
}

dir_size_human() {
    local path="$1"
    if [ -d "$path" ]; then
        du -sh "$path" 2>/dev/null | awk '{print $1}'
    else
        echo "0B"
    fi
}

confirm() {
    local prompt="$1"
    if $DRY_RUN; then
        return 1
    fi
    if $ASSUME_YES; then
        return 0
    fi
    printf "${CYAN}%s [y/N] ${RESET}" "$prompt"
    read -r answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

delete_path() {
    local path="$1"
    local label="$2"
    local bytes
    bytes=$(dir_size_bytes "$path")
    if [ "$bytes" -eq 0 ]; then
        return
    fi
    if $DRY_RUN; then
        printf "  ${DIM}would delete: %s (%s)${RESET}\n" "$path" "$(human_size "$bytes")"
    else
        rm -rf "$path"
        total_freed=$((total_freed + bytes))
        printf "  ${GREEN}deleted: %s (%s)${RESET}\n" "$label" "$(human_size "$bytes")"
    fi
}

delete_contents() {
    local path="$1"
    local label="$2"
    local bytes
    bytes=$(dir_size_bytes "$path")
    if [ "$bytes" -eq 0 ]; then
        return
    fi
    if $DRY_RUN; then
        printf "  ${DIM}would delete contents of: %s (%s)${RESET}\n" "$path" "$(human_size "$bytes")"
    else
        rm -rf "${path:?}"/*
        total_freed=$((total_freed + bytes))
        printf "  ${GREEN}deleted contents of: %s (%s)${RESET}\n" "$label" "$(human_size "$bytes")"
    fi
}

section_header() {
    local num="$1"
    local title="$2"
    local size="$3"
    printf "\n${BOLD}━━━ [%s] %s (%s) ━━━${RESET}\n" "$num" "$title" "$size"
}

# --- Banner ---

printf "\n${BOLD}╔══════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}║       Developer Cache Cleanup (macOS)        ║${RESET}\n"
printf "${BOLD}╚══════════════════════════════════════════════╝${RESET}\n"

if $DRY_RUN; then
    printf "${YELLOW}  DRY RUN — nothing will be deleted${RESET}\n"
fi
if $ASSUME_YES && ! $DRY_RUN; then
    printf "${YELLOW}  AUTO-YES — prompts will be skipped${RESET}\n"
fi

printf "\nSections: ${BOLD}%s${RESET}\n" "${SECTIONS[*]}"
printf "Scanning...\n"

# --- 1. Xcode DerivedData ---

if run_section xcode; then
    DERIVED_DATA="$HOME_DIR/Library/Developer/Xcode/DerivedData"
    size=$(dir_size_human "$DERIVED_DATA")
    section_header "1" "Xcode DerivedData" "$size"
    printf "  Build artifacts, index caches. Rebuilds automatically on next compile.\n"

    if [ -d "$DERIVED_DATA" ] && [ "$(dir_size_bytes "$DERIVED_DATA")" -gt 0 ]; then
        if $DRY_RUN; then
            delete_contents "$DERIVED_DATA" "DerivedData"
        elif confirm "Delete all DerivedData?"; then
            delete_contents "$DERIVED_DATA" "DerivedData"
        else
            printf "  ${DIM}skipped${RESET}\n"
        fi
    else
        printf "  ${DIM}nothing to clean${RESET}\n"
    fi
fi

# --- 2. Gradle caches ---

if run_section gradle; then
    GRADLE_CACHES="$HOME_DIR/.gradle/caches"
    GRADLE_WRAPPER="$HOME_DIR/.gradle/wrapper/dists"
    GRADLE_DAEMON="$HOME_DIR/.gradle/daemon"
    caches_bytes=$(dir_size_bytes "$GRADLE_CACHES")
    wrapper_bytes=$(dir_size_bytes "$GRADLE_WRAPPER")
    daemon_bytes=$(dir_size_bytes "$GRADLE_DAEMON")
    gradle_total=$((caches_bytes + wrapper_bytes + daemon_bytes))
    section_header "2" "Gradle (caches + wrapper + daemon)" "$(human_size $gradle_total)"
    printf "  Downloaded dependencies, wrapper distributions, daemon logs.\n"
    printf "  Re-downloads on next build.\n"

    if [ "$gradle_total" -gt 0 ]; then
        if $DRY_RUN; then
            delete_contents "$GRADLE_CACHES" "caches"
            delete_contents "$GRADLE_WRAPPER" "wrapper/dists"
            delete_contents "$GRADLE_DAEMON" "daemon"
        elif confirm "Delete Gradle caches, wrapper dists, and daemon logs?"; then
            delete_contents "$GRADLE_CACHES" "caches"
            delete_contents "$GRADLE_WRAPPER" "wrapper/dists"
            delete_contents "$GRADLE_DAEMON" "daemon"
        else
            printf "  ${DIM}skipped${RESET}\n"
        fi
    else
        printf "  ${DIM}nothing to clean${RESET}\n"
    fi
fi

# --- 3. Google caches (Android Studio / Chrome) ---

if run_section google; then
    GOOGLE_CACHES="$HOME_DIR/Library/Caches/Google"
    size=$(dir_size_human "$GOOGLE_CACHES")
    section_header "3" "Google caches (Android Studio / Chrome)" "$size"
    printf "  Android Studio and Chrome cache files.\n"

    if [ -d "$GOOGLE_CACHES" ] && [ "$(dir_size_bytes "$GOOGLE_CACHES")" -gt 0 ]; then
        if $DRY_RUN; then
            delete_contents "$GOOGLE_CACHES" "Google caches"
        elif confirm "Delete Google caches?"; then
            delete_contents "$GOOGLE_CACHES" "Google caches"
        else
            printf "  ${DIM}skipped${RESET}\n"
        fi
    else
        printf "  ${DIM}nothing to clean${RESET}\n"
    fi
fi

# --- 4. Old Android Studio app support ---

if run_section android-studio; then
    AS_SUPPORT="$HOME_DIR/Library/Application Support/Google"
    section_header "4" "Old Android Studio versions" ""
    printf "  Settings and caches from previous Android Studio installations.\n"
    printf "  Only old versions are shown — your latest is kept.\n\n"

    as_dirs=""
    as_count=0
    for dir in "$AS_SUPPORT"/AndroidStudio*; do
        if [ -d "$dir" ]; then
            as_dirs="$as_dirs
$dir"
            as_count=$((as_count + 1))
        fi
    done

    if [ "$as_count" -gt 1 ]; then
        i=0
        echo "$as_dirs" | tail -n +2 | while read -r dir; do
            [ -z "$dir" ] && continue
            i=$((i + 1))
            if [ "$i" -lt "$as_count" ]; then
                name=$(basename "$dir")
                s=$(dir_size_human "$dir")
                printf "  ${DIM}%s (%s)${RESET}\n" "$name" "$s"
            fi
        done

        latest=$(echo "$as_dirs" | tail -n +2 | tail -1)
        latest_name=$(basename "$latest")
        printf "  ${GREEN}keeping: %s (latest)${RESET}\n\n" "$latest_name"

        if $DRY_RUN; then
            echo "$as_dirs" | tail -n +2 | while read -r dir; do
                [ -z "$dir" ] && continue
                if [ "$dir" != "$latest" ]; then
                    delete_path "$dir" "$(basename "$dir")"
                fi
            done
        elif confirm "Delete all old Android Studio versions (keep $latest_name)?"; then
            echo "$as_dirs" | tail -n +2 | while read -r dir; do
                [ -z "$dir" ] && continue
                if [ "$dir" != "$latest" ]; then
                    delete_path "$dir" "$(basename "$dir")"
                fi
            done
        else
            printf "  ${DIM}skipped${RESET}\n"
        fi
    else
        printf "  ${DIM}only one version found, nothing to clean${RESET}\n"
    fi
fi

# --- 5. Android emulators (AVDs) ---

if run_section avd; then
    AVD_DIR="$HOME_DIR/.android/avd"
    section_header "5" "Android emulators (AVDs)" "$(dir_size_human "$AVD_DIR")"
    printf "  Each emulator listed individually — pick which to delete.\n\n"

    if [ -d "$AVD_DIR" ]; then
        found_avd=false
        for avd in "$AVD_DIR"/*.avd; do
            [ -d "$avd" ] || continue
            found_avd=true
            avd_name=$(basename "$avd" .avd)
            avd_size=$(dir_size_human "$avd")
            avd_bytes=$(dir_size_bytes "$avd")

            printf "  ${BOLD}%s${RESET} (%s)\n" "$avd_name" "$avd_size"

            if $DRY_RUN; then
                printf "    ${DIM}would delete${RESET}\n"
            elif confirm "  Delete $avd_name?"; then
                rm -rf "$avd"
                rm -f "$AVD_DIR/${avd_name}.ini"
                total_freed=$((total_freed + avd_bytes))
                printf "    ${GREEN}deleted${RESET}\n"
            else
                printf "    ${DIM}kept${RESET}\n"
            fi
        done
        if ! $found_avd; then
            printf "  ${DIM}no AVDs found${RESET}\n"
        fi
    else
        printf "  ${DIM}no AVD directory${RESET}\n"
    fi
fi

# --- 6. iOS Simulators (unavailable) ---

if run_section ios-sim; then
    section_header "6" "iOS Simulators (unavailable runtimes)" ""
    printf "  Removes simulators for iOS versions no longer installed.\n"

    unavailable_count=$(xcrun simctl list devices unavailable 2>/dev/null | grep -c "unavailable" || true)
    if [ "$unavailable_count" -gt 0 ]; then
        printf "  Found ${BOLD}%d${RESET} unavailable simulator(s)\n" "$unavailable_count"
        if $DRY_RUN; then
            printf "  ${DIM}would run: xcrun simctl delete unavailable${RESET}\n"
        elif confirm "Delete unavailable simulators?"; then
            xcrun simctl delete unavailable 2>/dev/null
            printf "  ${GREEN}cleaned up unavailable simulators${RESET}\n"
        else
            printf "  ${DIM}skipped${RESET}\n"
        fi
    else
        printf "  ${DIM}no unavailable simulators${RESET}\n"
    fi
fi

# --- 7. Homebrew cache ---

if run_section brew; then
    BREW_CACHE="$HOME_DIR/Library/Caches/Homebrew"
    size=$(dir_size_human "$BREW_CACHE")
    section_header "7" "Homebrew cache" "$size"
    printf "  Old downloads and bottle caches.\n"

    if [ -d "$BREW_CACHE" ] && [ "$(dir_size_bytes "$BREW_CACHE")" -gt 0 ]; then
        if $DRY_RUN; then
            printf "  ${DIM}would run: brew cleanup --prune=all${RESET}\n"
        elif confirm "Run brew cleanup --prune=all?"; then
            brew cleanup --prune=all 2>/dev/null
            printf "  ${GREEN}done${RESET}\n"
        else
            printf "  ${DIM}skipped${RESET}\n"
        fi
    else
        printf "  ${DIM}nothing to clean${RESET}\n"
    fi
fi

# --- 8. Maven cache ---

if run_section maven; then
    MAVEN_REPO="$HOME_DIR/.m2/repository"
    size=$(dir_size_human "$MAVEN_REPO")
    section_header "8" "Maven local repository" "$size"
    printf "  Downloaded Maven artifacts. Re-downloads on next build.\n"

    if [ -d "$MAVEN_REPO" ] && [ "$(dir_size_bytes "$MAVEN_REPO")" -gt 0 ]; then
        if $DRY_RUN; then
            delete_contents "$MAVEN_REPO" "Maven repository"
        elif confirm "Delete Maven local repository?"; then
            delete_contents "$MAVEN_REPO" "Maven repository"
        else
            printf "  ${DIM}skipped${RESET}\n"
        fi
    else
        printf "  ${DIM}nothing to clean${RESET}\n"
    fi
fi

# --- 9. CocoaPods cache ---

if run_section cocoapods; then
    PODS_CACHE="$HOME_DIR/Library/Caches/CocoaPods"
    size=$(dir_size_human "$PODS_CACHE")
    section_header "9" "CocoaPods cache" "$size"
    printf "  Cached pod specs and downloads.\n"

    if [ -d "$PODS_CACHE" ] && [ "$(dir_size_bytes "$PODS_CACHE")" -gt 0 ]; then
        if $DRY_RUN; then
            delete_contents "$PODS_CACHE" "CocoaPods cache"
        elif confirm "Delete CocoaPods cache?"; then
            delete_contents "$PODS_CACHE" "CocoaPods cache"
        else
            printf "  ${DIM}skipped${RESET}\n"
        fi
    else
        printf "  ${DIM}nothing to clean${RESET}\n"
    fi
fi

# --- 10. System logs ---

if run_section logs; then
    LOGS_DIR="$HOME_DIR/Library/Logs"
    size=$(dir_size_human "$LOGS_DIR")
    section_header "10" "User logs" "$size"
    printf "  Application and system logs in ~/Library/Logs.\n"

    if [ -d "$LOGS_DIR" ] && [ "$(dir_size_bytes "$LOGS_DIR")" -gt 0 ]; then
        if $DRY_RUN; then
            delete_contents "$LOGS_DIR" "Logs"
        elif confirm "Delete user logs?"; then
            delete_contents "$LOGS_DIR" "Logs"
        else
            printf "  ${DIM}skipped${RESET}\n"
        fi
    else
        printf "  ${DIM}nothing to clean${RESET}\n"
    fi
fi

# --- Summary ---

printf "\n${BOLD}━━━ Summary ━━━${RESET}\n"
if $DRY_RUN; then
    printf "${YELLOW}  Dry run complete — no files were deleted.${RESET}\n"
    printf "  Run without --dry-run to clean up.\n"
else
    if [ "$total_freed" -gt 0 ]; then
        printf "${GREEN}  Total freed: %s${RESET}\n" "$(human_size $total_freed)"
    else
        printf "  No changes made.\n"
    fi
fi
printf "\n"
