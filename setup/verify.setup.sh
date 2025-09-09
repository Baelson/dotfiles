#!/bin/zsh
#
# Validation Script for macOS Core Setup
#
# This script validates that all Phase 1 components are properly installed
# and configured before proceeding to subsequent phases
#
# Usage: ./setup/verify.setup.sh [OPTIONS]
#
# Options:
#   --debug-trace       Show control flow and decision points
#   --debug-verbose     Show detailed execution including variable assignments
#   --help             Display this help message
#

set -euo pipefail

# Global script flags
DEBUG_TRACE=false
DEBUG_VERBOSE=false

# Configuration and Common Library
readonly SCRIPT_DIR="${0:A:h}"

# Source common functions - should always be available
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/validation.sh"
init_logging "verify.setup"
setup_error_trap "verify.setup"
check_macos

#======================================
# Argument Parsing
#======================================

show_help() {
    show_standard_help "macOS Core Setup Verification Script" \
        "This script validates that all Phase 1 components are properly installed
and configured before proceeding to subsequent phases." \
        "./bootstrap/verify.setup.sh [OPTIONS]"
}

parse_arguments() {
    # Handle --help first
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

    # Only parse debug arguments for verification scripts (no --dry-run)
    debug_trace "→ Entering: parse_arguments"
    debug_trace "Current arguments: $*"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug-trace)
                export DEBUG_TRACE=true
                debug_verbose "Set DEBUG_TRACE=true"
                shift
                ;;
            --debug-verbose)
                export DEBUG_VERBOSE=true
                export DEBUG_TRACE=true  # verbose includes trace
                debug_verbose "Set DEBUG_VERBOSE=true, DEBUG_TRACE=true"
                shift
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

# Validation functions moved to bootstrap/lib/validation.sh

main() {
    debug_trace "→ Entering: main"

    # Use the comprehensive validation from the validation module
    if run_comprehensive_validation; then
        log "Ready to proceed to Phase 2: Chezmoi Migration"
        debug_trace "← Exiting: main (success)"
        return 0
    else
        debug_trace "← Exiting: main (failure)"
        return 1
    fi
}

# Handle script interruption
trap 'log_error "Verification script interrupted"; exit 1' INT TERM

# Parse arguments and run main function
parse_arguments "$@"
main
