#!/bin/zsh
#
# macOS System and Environment Setup (macSES) - Core Setup Script
#
# This script handles the core installation after the repository has been cloned.
# It focuses on installing Xcode CLI Tools and Homebrew.
#
# Usage: ./setup/setup.core.sh [OPTIONS]
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
source "$SCRIPT_DIR/lib/xcode.sh"
source "$SCRIPT_DIR/lib/homebrew.sh"
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
        "./scripts/setup/setup.core.sh [OPTIONS]"
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
    time_operation "Xcode CLI Tools Installation" install_xcode_cli_tools

    # Step 2: Install Homebrew
    ((++current_step))
    show_progress $current_step $total_steps "Installing Homebrew..."
    time_operation "Homebrew Installation" install_homebrew

    # Step 3: Run validation
    ((++current_step))
    show_progress $current_step $total_steps "Running validation..."
    time_operation "System Validation" run_validation

    log_success "🎉 Phase 1: Core Foundation completed successfully!"
    echo ""
    log "📍 Next Steps:"
    log "  1. Run 'cd $REPO_DIR && ./scripts/setup/setup.macos.sh' to continue with macOS-specific setup"
    log "  2. Review the docs/PRD.md and CLAUDE.md for full project details"
    log "  3. Logs available at: $LOG_FILE"

    debug_trace "← Exiting: main"
}

# install_xcode_cli_tools() function moved to bootstrap/lib/xcode.sh

# install_homebrew() function moved to bootstrap/lib/homebrew.sh

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
