#!/bin/zsh
#
# macOS System and Environment Setup (macSES) - Core Setup Script
#
# This script handles the core installation after the repository has been cloned.
# It focuses on installing Xcode CLI Tools and Homebrew.
#
# Usage: ./bootstrap/setup.core.sh [OPTIONS]
#
# Options:
#   --dry-run           Preview operations without executing (uses tools' native dry-run when available)
#   --debug-trace       Show control flow and decision points
#   --debug-verbose     Show detailed execution including variable assignments
#   --help             Display this help message
#
# Phase 1: Core Foundation
# - Install Xcode CLI Tools
# - Install Homebrew
# - Run validation checks
#

set -euo pipefail

# Global script flags
DRY_RUN=false
DEBUG_TRACE=false
DEBUG_VERBOSE=false

# Configuration and Common Library
readonly SCRIPT_DIR="$(cd "${0:A:h}" && pwd)"

# Source common functions - should always be available
source "$SCRIPT_DIR/lib/common.sh"
init_logging "setup.core"
setup_error_trap "setup.core"
check_macos

#======================================
# Argument Parsing
#======================================

show_help() {
    show_standard_help "macOS Core Setup Script" \
        "This script handles core macOS development environment setup.
Installs Xcode CLI Tools and Homebrew after repository is available." \
        "./bootstrap/setup.core.sh [OPTIONS]"
}

parse_arguments() {
    # Handle --help first
    for arg in "$@"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
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
# Main Setup Functions
#======================================

main() {
    debug_trace "→ Entering: main"

    local current_step=0
    local total_steps=3

    log "🔧 Starting Core macOS Development Environment Setup..."
    log "📍 Repository: $REPO_DIR"
    echo ""

    # Step 1: Install Xcode CLI Tools
    ((++current_step))
    show_progress $current_step $total_steps "Installing Xcode CLI Tools..."
    install_xcode_cli_tools

    # Step 2: Install Homebrew
    ((++current_step))
    show_progress $current_step $total_steps "Installing Homebrew..."
    install_homebrew

    # Step 3: Run validation
    ((++current_step))
    show_progress $current_step $total_steps "Running validation..."
    run_validation

    log_success "🎉 Phase 1: Core Foundation completed successfully!"
    echo ""
    log "📍 Next Steps:"
    log "  1. Run 'cd $REPO_DIR && ./bootstrap/setup.macos.sh' to continue with macOS-specific setup"
    log "  2. Review the docs/PRD.md and CLAUDE.md for full project details"
    log "  3. Logs available at: $LOG_FILE"

    debug_trace "← Exiting: main"
}

install_xcode_cli_tools() {
    debug_trace "→ Entering: install_xcode_cli_tools"

    if xcode-select --print-path &> /dev/null; then
        log_success "Xcode CLI Tools already installed"
        debug_trace "← Exiting: install_xcode_cli_tools (already installed)"
        return 0
    fi

    log "Installing Xcode Command Line Tools..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would run: xcode-select --install"
        log_dry_run "Would wait for installation to complete with user interaction"
        debug_trace "← Exiting: install_xcode_cli_tools (dry-run)"
        return 0
    fi

    # Trigger the installation
    debug_verbose "Triggering Xcode CLI Tools installation"
    xcode-select --install &> /dev/null || true

    # Wait for installation to complete
    log "Waiting for Xcode CLI Tools installation to complete..."
    log "⏳ This may take several minutes and require user interaction..."

    local timeout=600  # 10 minutes timeout
    local elapsed=0

    until xcode-select --print-path &> /dev/null; do
        sleep 5
        ((elapsed += 5))

        if [[ $elapsed -ge $timeout ]]; then
            log_error "Xcode CLI Tools installation timed out after ${timeout} seconds"
            log_error "Please check the installation manually and try again"
            exit 1
        fi
    done

    log_success "Xcode CLI Tools installed successfully"
    debug_trace "← Exiting: install_xcode_cli_tools"
}

install_homebrew() {
    debug_trace "→ Entering: install_homebrew"

    if command -v brew &> /dev/null; then
        log_success "Homebrew already installed"
        debug_trace "← Exiting: install_homebrew (already installed)"
        return 0
    fi

    log "Installing Homebrew..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would install Homebrew using official installer"
        log_dry_run "Would add Homebrew to PATH based on architecture"
        debug_trace "← Exiting: install_homebrew (dry-run)"
        return 0
    fi

    # Install Homebrew using the official installer
    # single-line CLI: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    debug_verbose "Installing Homebrew with explicit bash shebang handling"
    local homebrew_install_script="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

    /bin/bash -c "$(curl \
        --fail \
        --silent \
        --show-error \
        --location \
        "$homebrew_install_script")" || {
        log_error "Failed to install Homebrew"
        log_error "Please check the official installation guide at https://brew.sh"
        exit 1
    }

    # Add Homebrew to PATH based on architecture
    debug_verbose "Configuring Homebrew PATH for current architecture"
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        # Apple Silicon
        debug_verbose "Detected Apple Silicon, using /opt/homebrew"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        # Intel
        debug_verbose "Detected Intel Mac, using /usr/local"
        eval "$(/usr/local/bin/brew shellenv)"
    else
        log_error "Could not find Homebrew installation"
        exit 1
    fi

    log_success "Homebrew installed and configured successfully"
    debug_trace "← Exiting: install_homebrew"
}

run_validation() {
    debug_trace "→ Entering: run_validation"
    log "🔍 Running core setup validation..."

    # Run the verification script
    if [[ -f "$SCRIPT_DIR/verify.setup.sh" ]]; then
        if [[ "$DEBUG_TRACE" == "true" || "$DEBUG_VERBOSE" == "true" ]]; then
            local debug_flags=""
            [[ "$DEBUG_TRACE" == "true" ]] && debug_flags="--debug-trace"
            [[ "$DEBUG_VERBOSE" == "true" ]] && debug_flags="--debug-verbose"

            "$SCRIPT_DIR/verify.setup.sh" $debug_flags
        else
            "$SCRIPT_DIR/verify.setup.sh"
        fi
    else
        log_warning "Verification script not found, skipping validation"
    fi

    debug_trace "← Exiting: run_validation"
}

# Handle script interruption
trap 'log_error "Core setup script interrupted"; exit 1' INT TERM

# Parse arguments and run main function
parse_arguments "$@"
main
