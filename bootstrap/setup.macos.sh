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

#======================================
# Debug and Dry-Run Functions
#======================================

debug_trace() {
    if [[ "$DEBUG_TRACE" == "true" || "$DEBUG_VERBOSE" == "true" ]]; then
        echo "[TRACE] $1" >&2
    fi
    return 0
}

debug_verbose() {
    if [[ "$DEBUG_VERBOSE" == "true" ]]; then
        echo "[DEBUG] $1" >&2
    fi
    return 0
}

log_dry_run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] $1"
    fi
    return 0
}

run_with_native_dry_run() {
    local tool="$1"
    local dry_run_flag="$2"
    local actual_cmd="$3"
    local description="$4"

    debug_trace "→ Entering: $description"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Running $tool dry-run preview:"
        local dry_run_cmd="$tool $dry_run_flag"
        debug_verbose "Dry-run command: $dry_run_cmd"
        eval "$dry_run_cmd"
        debug_trace "← Exiting: $description (dry-run)"
        return 0
    fi

    debug_verbose "Executing: $actual_cmd"
    eval "$actual_cmd"
    local exit_code=$?
    debug_trace "← Exiting: $description (exit code: $exit_code)"
    return $exit_code
}

run_command() {
    local cmd="$1"
    local description="$2"

    debug_trace "→ Entering: $description"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would run: $cmd"
        debug_trace "← Exiting: $description (dry-run)"
        return 0
    fi

    debug_verbose "Executing: $cmd"
    eval "$cmd"
    local exit_code=$?
    debug_trace "← Exiting: $description (exit code: $exit_code)"
    return $exit_code
}

#======================================
# Help and Argument Parsing
#======================================

show_help() {
    cat << 'EOF'
macOS-specific Setup Script

This script handles macOS-specific configuration and package installation.
Run after the initial bootstrap (setup.core.sh) completes.

USAGE:
    ./bootstrap/setup.macos.sh [OPTIONS]

OPTIONS:
    --dry-run           Preview operations without executing
    --debug-trace       Show control flow and decision points  
    --debug-verbose     Show detailed execution including variables
    --help             Display this help message

EXAMPLES:
    ./bootstrap/setup.macos.sh
    ./bootstrap/setup.macos.sh --dry-run
    ./bootstrap/setup.macos.sh --debug-verbose

EOF
}

parse_arguments() {
    debug_trace "→ Entering: parse_arguments"
    debug_trace "Current arguments: $@"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                debug_verbose "Set DRY_RUN=true"
                shift
                ;;
            --debug-trace)
                DEBUG_TRACE=true
                debug_verbose "Set DEBUG_TRACE=true"
                shift
                ;;
            --debug-verbose)
                DEBUG_VERBOSE=true
                DEBUG_TRACE=true  # verbose includes trace
                debug_verbose "Set DEBUG_VERBOSE=true, DEBUG_TRACE=true"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    debug_trace "← Exiting: parse_arguments"
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
