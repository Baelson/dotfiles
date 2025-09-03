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
                --dry-run|--debug-trace|--debug-verbose)
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

main() {
    debug_trace "→ Entering: main"
    log "🔧 Starting macOS-specific setup..."

    # Ensure we're in the correct directory
    cd "$REPO_DIR"

    # Install packages from Brewfile
    install_packages

    # Run basic macOS configuration
    configure_macos

    log_success "macOS-specific setup completed!"
    log "Next: Phase 2 (Chezmoi Migration) - See docs/PRD.md for details"
    debug_trace "← Exiting: main"
}

install_packages() {
    debug_trace "→ Entering: install_packages"
    log "📦 Installing packages from Brewfile..."

    # Validate REPO_DIR is set and accessible
    if [[ -z "${REPO_DIR:-}" ]]; then
        log_error "REPO_DIR is not set"
        exit 1
    fi

    if [[ ! -d "$REPO_DIR" ]]; then
        log_error "Repository directory does not exist: $REPO_DIR"
        exit 1
    fi

    if [ ! -f "$REPO_DIR/Brewfile" ]; then
        log_error "Brewfile not found in $REPO_DIR"
        exit 1
    fi

    # Install packages using brew bundle
    # single-line CLI: brew bundle --file="$REPO_DIR/Brewfile"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would install packages using: brew bundle --file=\"$REPO_DIR/Brewfile\""
        log_dry_run "Use 'brew bundle check --file=\"$REPO_DIR/Brewfile\"' to see what would be installed"
        # Show what would be installed
        debug_verbose "Checking Brewfile contents for preview"
        run_command "brew bundle check --verbose --file=\"$REPO_DIR/Brewfile\"" "Checking Brewfile status"
    else
        debug_verbose "Installing packages with: brew bundle --file=\"$REPO_DIR/Brewfile\""
        brew bundle --file="$REPO_DIR/Brewfile" || {
            log_error "Failed to install packages from Brewfile"
            exit 1
        }
    fi

    log_success "Packages installed successfully"
    debug_trace "← Exiting: install_packages"
}

configure_macos() {
    debug_trace "→ Entering: configure_macos"
    log "⚙️  Applying basic macOS configuration..."

    # Enable key repeat for all applications
    run_command "defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false" "Disable press-and-hold for keys"

    # Set faster key repeat rates
    run_command "defaults write NSGlobalDomain KeyRepeat -int 2" "Set fast key repeat rate"
    run_command "defaults write NSGlobalDomain InitialKeyRepeat -int 15" "Set fast initial key repeat"

    # Show all filename extensions in Finder
    run_command "defaults write NSGlobalDomain AppleShowAllExtensions -bool true" "Show all file extensions"

    # Show hidden files in Finder
    run_command "defaults write com.apple.finder AppleShowAllFiles -bool true" "Show hidden files in Finder"

    # Restart Finder to apply changes
    run_command "killall Finder &> /dev/null || true" "Restart Finder to apply changes"

    log_success "Basic macOS configuration applied"
    debug_trace "← Exiting: configure_macos"
}

# Handle script interruption
trap 'log_error "macOS setup script interrupted"; exit 1' INT TERM

# Parse arguments and run main function
parse_arguments "$@"
main
