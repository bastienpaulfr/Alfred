#!/usr/bin/env zsh

# Update package managers and tools
# Simple script to keep development tools up to date

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}=== Updating Development Tools ===${NC}\n"

# Update Homebrew
update_brew() {
    echo "${YELLOW}Updating Homebrew...${NC}"
    if command -v brew &> /dev/null; then
        brew update && brew upgrade
        echo "${GREEN}✓ Homebrew updated${NC}\n"
    else
        echo "${RED}✗ Homebrew not found${NC}\n"
    fi
}

# Future: Add more package managers here
# update_npm() { ... }
# update_pip() { ... }
# update_cargo() { ... }

# Run all updates
update_brew

echo "${GREEN}=== All updates complete! ===${NC}"
