#!/bin/bash
# ============================================================================
# IBM Power Systems Infrastructure Collection - Packaging Script
# ============================================================================
#
# Description:
#   Creates a distributable tar.gz archive containing all files needed to
#   run the IBM Power Systems infrastructure collection playbooks. Excludes
#   the packaging script itself and all files/directories listed in .gitignore.
#
# Usage:
#   ./package.sh [output_filename]
#
# Arguments:
#   output_filename - Optional. Name for the output archive (without .tar.gz)
#                     Default: ibm-power-infrastructure-collection-YYYYMMDD-HHMMSS
#
# Examples:
#   ./package.sh                           # Uses default timestamped name
#   ./package.sh my-custom-package         # Creates my-custom-package.tar.gz
#
# Output:
#   Creates a .tar.gz archive in the current directory containing:
#   - All playbooks (*.yml)
#   - Templates directory
#   - Inventory directory (with examples)
#   - Vars directory (with vault.yml.example)
#   - Configuration files (ansible.cfg, requirements.yml)
#   - Documentation (README.md, COMPARISON.md)
#   - Directory structure (empty output directories)
#
# Excluded (from .gitignore):
#   - Generated reports (*.json, *.csv, *.yml, *.html in output/reports/)
#   - Vault password files (.vault_pass)
#   - Actual vault.yml (only includes vault.yml.example)
#   - Python cache and virtual environments
#   - IDE configuration files
#   - OS-specific files (.DS_Store, Thumbs.db)
#   - Temporary and backup files
#   - This packaging script itself
#
# Notes:
#   - Preserves directory structure
#   - Maintains file permissions
#   - Creates empty output directories for reports
#   - Safe to run multiple times
# Version: See VERSION file in project root
# Last Updated: 2026-02-27
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_NAME="ibm-power-infrastructure-collection"

# Generate default output filename with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEFAULT_OUTPUT="${PROJECT_NAME}-${TIMESTAMP}"

# Use provided filename or default
OUTPUT_NAME="${1:-$DEFAULT_OUTPUT}"
OUTPUT_FILE="${OUTPUT_NAME}.tar.gz"

# Temporary directory for staging
TEMP_DIR=$(mktemp -d)
STAGE_DIR="${TEMP_DIR}/${PROJECT_NAME}"

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Print functions
print_header() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Main execution
main() {
    print_header "IBM Power Systems Infrastructure Collection - Packaging"
    
    echo ""
    print_info "Project directory: ${SCRIPT_DIR}"
    print_info "Output file: ${OUTPUT_FILE}"
    print_info "Staging directory: ${STAGE_DIR}"
    echo ""
    
    # Check if .gitignore exists
    if [ ! -f "${SCRIPT_DIR}/.gitignore" ]; then
        print_warning ".gitignore not found, will package all files except this script"
    fi
    
    # Create staging directory
    print_info "Creating staging directory..."
    mkdir -p "$STAGE_DIR"
    
    # Copy all files except those in .gitignore and the script itself
    print_info "Copying project files..."
    
    cd "$SCRIPT_DIR"
    
    # Create list of files to include
    if [ -f .gitignore ]; then
        # Use git ls-files if in a git repo, otherwise use find
        if git rev-parse --git-dir > /dev/null 2>&1; then
            print_info "Using git to determine files to include..."
            git ls-files | while read -r file; do
                # Exclude the script itself, .gitignore, and .gitkeep files
                if [ "$file" != "$SCRIPT_NAME" ] && [ "$file" != ".gitignore" ] && [ "$(basename "$file")" != ".gitkeep" ]; then
                    mkdir -p "$STAGE_DIR/$(dirname "$file")"
                    cp -p "$file" "$STAGE_DIR/$file"
                fi
            done
        else
            print_info "Not a git repository, using find with .gitignore patterns..."
            # Build exclude patterns from .gitignore
            EXCLUDE_ARGS=""
            while IFS= read -r line; do
                # Skip empty lines and comments
                if [ -n "$line" ] && [ "${line:0:1}" != "#" ]; then
                    # Remove leading/trailing whitespace
                    pattern=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [ -n "$pattern" ]; then
                        EXCLUDE_ARGS="$EXCLUDE_ARGS -not -path '*/$pattern' -not -path '*/$pattern/*'"
                    fi
                fi
            done < .gitignore
            
            # Find and copy files (exclude script, .gitignore, .gitkeep)
            eval "find . -type f $EXCLUDE_ARGS -not -name '$SCRIPT_NAME' -not -name '.gitignore' -not -name '.gitkeep' -not -path './.git/*'" | while read -r file; do
                rel_path="${file#./}"
                mkdir -p "$STAGE_DIR/$(dirname "$rel_path")"
                cp -p "$file" "$STAGE_DIR/$rel_path"
            done
        fi
    else
        # No .gitignore, copy everything except the script, .gitignore, and .gitkeep
        print_info "Copying all files except packaging script..."
        find . -type f -not -name "$SCRIPT_NAME" -not -name '.gitignore' -not -name '.gitkeep' -not -path './.git/*' | while read -r file; do
            rel_path="${file#./}"
            mkdir -p "$STAGE_DIR/$(dirname "$rel_path")"
            cp -p "$file" "$STAGE_DIR/$rel_path"
        done
    fi
    
    # Ensure output directory structure exists (even if empty)
    print_info "Creating output directory structure..."
    mkdir -p "$STAGE_DIR/output/reports"
    
    # Count files
    FILE_COUNT=$(find "$STAGE_DIR" -type f | wc -l | tr -d ' ')
    print_info "Packaged ${FILE_COUNT} files"
    
    # Create tar archive
    print_info "Creating tar.gz archive..."
    cd "$TEMP_DIR"
    tar -czf "${SCRIPT_DIR}/${OUTPUT_FILE}" "$PROJECT_NAME"
    
    # Get archive size
    ARCHIVE_SIZE=$(du -h "${SCRIPT_DIR}/${OUTPUT_FILE}" | cut -f1)
    
    echo ""
    print_success "Package created successfully!"
    echo ""
    echo -e "${GREEN}Archive Details:${NC}"
    echo "  File: ${OUTPUT_FILE}"
    echo "  Size: ${ARCHIVE_SIZE}"
    echo "  Files: ${FILE_COUNT}"
    echo ""
    echo -e "${BLUE}To extract:${NC}"
    echo "  tar -xzf ${OUTPUT_FILE}"
    echo ""
    echo -e "${BLUE}Contents:${NC}"
    tar -tzf "${SCRIPT_DIR}/${OUTPUT_FILE}" | head -20
    if [ "$FILE_COUNT" -gt 20 ]; then
        echo "  ... and $((FILE_COUNT - 20)) more files"
    fi
    echo ""
}

# Run main function
main "$@"