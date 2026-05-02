#!/usr/bin/env zsh

# Install script for update-packages LaunchAgent
# This script sets up automatic daily package updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="${0:a:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

# Paths
PLIST_TEMPLATE="${SCRIPT_DIR}/com.user.update-packages.plist"
PLIST_NAME="com.user.update-packages.plist"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
INSTALLED_PLIST="${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"
UPDATE_SCRIPT="${SCRIPT_DIR}/update-packages.sh"
LOG_DIR="${HOME}/Library/Logs/update-packages"

echo "${BLUE}=== Installing Update Packages LaunchAgent ===${NC}\n"

# Check if update-packages.sh exists
if [[ ! -f "${UPDATE_SCRIPT}" ]]; then
    echo "${RED}✗ Error: update-packages.sh not found at ${UPDATE_SCRIPT}${NC}"
    exit 1
fi

# Make sure the script is executable
chmod +x "${UPDATE_SCRIPT}"
echo "${GREEN}✓ Script is executable${NC}"

# Create LaunchAgents directory if it doesn't exist
mkdir -p "${LAUNCH_AGENTS_DIR}"
echo "${GREEN}✓ LaunchAgents directory ready${NC}"

# Create log directory
mkdir -p "${LOG_DIR}"
echo "${GREEN}✓ Log directory created at ${LOG_DIR}${NC}"

# Unload existing agent if it's loaded
if launchctl list | grep -q "com.user.update-packages"; then
    echo "${YELLOW}Unloading existing LaunchAgent...${NC}"
    launchctl unload "${INSTALLED_PLIST}" 2>/dev/null || true
fi

# Remove existing plist if it exists
if [[ -f "${INSTALLED_PLIST}" ]] || [[ -L "${INSTALLED_PLIST}" ]]; then
    echo "${YELLOW}Removing existing plist...${NC}"
    rm "${INSTALLED_PLIST}"
fi

# Create plist with correct paths
echo "${YELLOW}Creating plist with correct paths...${NC}"
sed -e "s|SCRIPT_PATH_PLACEHOLDER|${UPDATE_SCRIPT}|g" \
    -e "s|LOG_DIR_PLACEHOLDER|${LOG_DIR}|g" \
    "${PLIST_TEMPLATE}" > "${INSTALLED_PLIST}"

echo "${GREEN}✓ Plist installed at ${INSTALLED_PLIST}${NC}"

# Load the LaunchAgent
echo "${YELLOW}Loading LaunchAgent...${NC}"
launchctl load "${INSTALLED_PLIST}"
echo "${GREEN}✓ LaunchAgent loaded${NC}"

# Verify it's loaded
if launchctl list | grep -q "com.user.update-packages"; then
    echo "\n${GREEN}=== Installation Complete! ===${NC}\n"
    echo "The update-packages script will run daily at 9:00 AM"
    echo ""
    echo "Logs will be written to:"
    echo "  Output: ${LOG_DIR}/update-packages.log"
    echo "  Errors: ${LOG_DIR}/update-packages-error.log"
    echo ""
    echo "Useful commands:"
    echo "  Test now:    launchctl start com.user.update-packages"
    echo "  Check logs:  tail -f ${LOG_DIR}/update-packages.log"
    echo "  Uninstall:   launchctl unload ${INSTALLED_PLIST} && rm ${INSTALLED_PLIST}"
else
    echo "\n${RED}✗ Warning: LaunchAgent may not have loaded correctly${NC}"
    echo "Check: launchctl list | grep update-packages"
fi
