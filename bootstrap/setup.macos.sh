#!/bin/zsh
#
# macOS-specific Setup Script
#
# This script handles macOS-specific configuration and package installation
# Run after the initial bootstrap (setup.core.sh) completes
#
# Usage: ./bootstrap/setup.macos.sh [OPTIONS]
#
# Options:
#   --dry-run           Preview operations without executing (uses tools' native dry-run when available)
#   --debug-trace       Show control flow and decision points
#   --debug-verbose     Show detailed execution including variable assignments
#   --help             Display this help message
#

set -euo pipefail

# Global script flags
DRY_RUN=false
DEBUG_TRACE=false
DEBUG_VERBOSE=false

# Configuration and Common Library
readonly SCRIPT_DIR="$(cd "${0:A:h}" && pwd)"

# Source common functions - should always be available after setup.core.sh
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/packages.sh"
source "$SCRIPT_DIR/lib/chezmoi.sh"
source "$SCRIPT_DIR/lib/macos.sh"
init_logging "setup.macos"
setup_error_trap "setup.macos"
check_macos

# Debug and dry-run functions are now provided by lib/common.sh

#======================================
# Argument Parsing
#======================================

show_help() {
    show_standard_help "macOS-specific Setup Script" \
        "This script handles macOS-specific configuration and package installation.
Run after the initial bootstrap (setup.core.sh) completes." \
        "./bootstrap/setup.macos.sh [OPTIONS]"
}

parse_arguments() {
    # Handle --help first
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

    # Parse other arguments
    parse_standard_arguments "$@"
    local result=$?

    if [[ $result -eq 2 ]]; then
        # Unknown argument encountered
        for arg in "$@"; do
            case $arg in
                --dry-run|-n|--debug-trace|-t|--debug-verbose|-v)
                    ;;
                *)
                    log_error "Unknown option: $arg"
                    show_help
                    exit 1
                    ;;
            esac
        done
    fi
}

#======================================
# Main Function - Script Overview
#======================================

main() {
    debug_trace "→ Entering: main"
    log "🔧 Starting macOS-specific setup..."

    # Ensure we're in the correct directory
    cd "$REPO_DIR"

    # Install packages from Brewfile
    time_operation "Package Installation" install_packages

    # Apply dotfiles configuration
    time_operation "Dotfiles Configuration" apply_dotfiles_configuration

    # Run basic macOS configuration
    time_operation "macOS Configuration" configure_macos

    log_success "macOS-specific setup completed!"
    log "✅ Phase 2 (Chezmoi Migration) completed - dotfiles applied successfully"
    debug_trace "← Exiting: main"
}

#======================================
# Setup Functions
#======================================

# apply_dotfiles_configuration() function moved to bootstrap/lib/chezmoi.sh

# install_packages() function moved to bootstrap/lib/packages.sh

# configure_macos() function moved to bootstrap/lib/macos.sh

# Handle script interruption
trap 'log_error "macOS setup script interrupted"; exit 1' INT TERM

# Parse arguments and run main function
parse_arguments "$@"
main
