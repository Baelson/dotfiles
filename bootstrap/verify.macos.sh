#!/bin/zsh
#
# Verification Script for macOS-specific Setup
#
# This script validates that all macOS-specific components from setup.macos.sh
# are properly installed and configured
#
# Usage: ./bootstrap/verify.macos.sh [OPTIONS]
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
readonly SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"

# Source common functions - should always be available after setup.core.sh
source "$SCRIPT_DIR/lib/common.sh"
init_logging "verify.macos"
setup_error_trap "verify.macos"
check_macos

# Debug functions are now provided by lib/common.sh

#======================================
# Argument Parsing
#======================================

show_help() {
    show_standard_help "macOS Setup Verification Script" \
        "This script validates that all macOS-specific components from setup.macos.sh\nare properly installed and configured." \
        "./bootstrap/verify.macos.sh [OPTIONS]"
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

# Validation counters
validation_passed=0
validation_failed=0

validate_item() {
    local description="$1"
    local command="$2"

    debug_trace "→ Validating: $description"
    debug_verbose "Validation command: $command"

    if eval "$command" &> /dev/null; then
        log_success "$description"
        ((++validation_passed))
        debug_trace "← Validation passed: $description"
        return 0
    else
        log_error "$description"
        ((++validation_failed))
        debug_trace "← Validation failed: $description"
        return 1
    fi
}

main() {
    debug_trace "→ Entering: main"
    log "🔍 Verifying macOS-specific setup components..."
    echo ""

    # Brewfile Package Verification
    log "📦 Brewfile Package Verification:"
    if [ -f "$REPO_DIR/Brewfile" ]; then
        # Core CLI tools
        validate_item "git package" 'brew list git'
        validate_item "uv package" 'brew list uv'
        validate_item "mas package" 'brew list mas'
        validate_item "antigen package" 'brew list antigen'
        validate_item "neovim package" 'brew list neovim'

        # Key casks
        validate_item "visual-studio-code cask" 'brew list --cask visual-studio-code'
        validate_item "iterm2 cask" 'brew list --cask iterm2'
        validate_item "docker cask" 'brew list --cask docker'

        # Sample MAS apps (if signed in)
        if mas account &> /dev/null; then
            validate_item "Xcode MAS app" 'mas list | grep -q Xcode'
            validate_item "Keynote MAS app" 'mas list | grep -q Keynote'
        else
            log_warning "Not signed into Mac App Store - skipping MAS app verification"
        fi
    else
        log_error "Brewfile not found at $REPO_DIR/Brewfile"
    fi
    echo ""

    # macOS Configuration Verification
    log "⚙️  macOS Configuration Verification:"

    # Key repeat settings
    local key_repeat=$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo "not set")
    if [ "$key_repeat" = "2" ]; then
        log_success "Fast key repeat enabled (KeyRepeat=2)"
    else
        log_warning "Key repeat setting: $key_repeat (expected: 2)"
    fi

    # Initial key repeat
    local initial_repeat=$(defaults read NSGlobalDomain InitialKeyRepeat 2>/dev/null || echo "not set")
    if [ "$initial_repeat" = "15" ]; then
        log_success "Fast initial key repeat enabled (InitialKeyRepeat=15)"
    else
        log_warning "Initial key repeat setting: $initial_repeat (expected: 15)"
    fi

    # Show all extensions
    local show_extensions=$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null || echo "not set")
    if [ "$show_extensions" = "1" ]; then
        log_success "Show all file extensions enabled"
    else
        log_warning "Show all extensions setting: $show_extensions (expected: 1)"
    fi

    # Show hidden files
    local show_hidden=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || echo "not set")
    if [ "$show_hidden" = "1" ]; then
        log_success "Show hidden files in Finder enabled"
    else
        log_warning "Show hidden files setting: $show_hidden (expected: 1)"
    fi
    echo ""

    # Summary
    log "📊 macOS Setup Verification Summary:"
    log "   ✅ Passed: $validation_passed checks"
    log "   ❌ Failed: $validation_failed checks"
    echo ""

    if [ $validation_failed -eq 0 ]; then
        log_success "🎉 All macOS-specific setup components verified!"
        log "macOS configuration is properly applied"
        [[ -n "${LOG_FILE:-}" ]] && log "Log file: $LOG_FILE"
        debug_trace "← Exiting: main (success)"
        return 0
    else
        log_error "❌ Some macOS setup components failed verification"
        log "Consider re-running setup.macos.sh to fix issues"
        [[ -n "${LOG_FILE:-}" ]] && log "Log file: $LOG_FILE"
        debug_trace "← Exiting: main (failure)"
        return 1
    fi
}

# Handle script interruption
trap 'log_error "macOS verification script interrupted"; exit 1' INT TERM

# Parse arguments and run main function
parse_arguments "$@"
main
