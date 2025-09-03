#!/bin/zsh
#
# Validation Script for macOS Core Setup
# 
# This script validates that all Phase 1 components are properly installed
# and configured before proceeding to subsequent phases
#
# Usage: ./bootstrap/verify.setup.sh [OPTIONS]
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
    log "🔍 Running Phase 1 validation checks..."
    echo ""
    
    # System Requirements
    log "📋 System Requirements:"
    validate_item "macOS operating system" '[[ "$OSTYPE" == "darwin"* ]]'
    validate_item "zsh shell available" 'command -v zsh'
    validate_item "curl available" 'command -v curl'
    validate_item "git available" 'command -v git'
    echo ""
    
    # Development Tools
    log "🛠  Development Tools:"
    validate_item "Xcode CLI Tools installed" 'xcode-select --print-path'
    validate_item "Homebrew installed" 'command -v brew'
    echo ""
    
    # Repository Structure
    log "📁 Repository Structure:"
    validate_item "Repository cloned" '[ -d "$REPO_DIR/.git" ]'
    validate_item "Brewfile exists" '[ -f "$REPO_DIR/Brewfile" ]'
    validate_item "CLAUDE.md exists" '[ -f "$REPO_DIR/CLAUDE.md" ]'
    validate_item "Bootstrap scripts exist" '[ -f "$REPO_DIR/bootstrap/setup.core.sh" -a -f "$REPO_DIR/bootstrap/setup.macos.sh" ]'
    validate_item "Common library exists" '[ -f "$REPO_DIR/bootstrap/lib/common.sh" ]'
    echo ""
    
    # Optional: Check Homebrew packages if Brewfile was processed
    if command -v brew &> /dev/null && [ -f "$REPO_DIR/Brewfile" ]; then
        log "📦 Homebrew Package Status:"
        
        # Check a few key packages that should be installed
        local key_packages=("git" "mas" "antigen" "chezmoi")
        for package in "${key_packages[@]}"; do
            if brew list "$package" &> /dev/null; then
                log_success "$package installed"
                ((++validation_passed))
            else
                log_warning "$package not yet installed (run setup.macos.sh)"
            fi
        done
        echo ""
    fi

    # Chezmoi Configuration
    if command -v chezmoi &> /dev/null; then
        log "🏠 Chezmoi Configuration:"
        validate_item "chezmoi external config exists" '[ -f "$REPO_DIR/.chezmoiexternal.toml" ]'
        validate_item "chezmoi ignore config exists" '[ -f "$REPO_DIR/.chezmoiignore" ]'
        validate_item "chezmoi doctor passes" 'chezmoi doctor --quiet'
        
        # Check if external archives are available
        if [ -d "$HOME/.local/share/antigen" ]; then
            log_success "External archive: antigen downloaded"
            ((++validation_passed))
        else
            log_warning "External archive: antigen not yet downloaded (run chezmoi apply)"
        fi
        
        if [ -d "$HOME/.local/share/oh-my-zsh" ]; then
            log_success "External archive: oh-my-zsh downloaded" 
            ((++validation_passed))
        else
            log_warning "External archive: oh-my-zsh not yet downloaded (run chezmoi apply)"
        fi
        
        if [ -d "$HOME/.local/share/dircolors" ]; then
            log_success "External archive: dircolors downloaded"
            ((++validation_passed))
        else
            log_warning "External archive: dircolors not yet downloaded (run chezmoi apply)"
        fi
        echo ""
    fi
    
    # Summary
    log "📊 Validation Summary:"
    log "   ✅ Passed: $validation_passed checks"
    log "   ❌ Failed: $validation_failed checks"
    echo ""
    
    if [ $validation_failed -eq 0 ]; then
        log_success "🎉 All validations passed! Phase 1 setup is complete."
        log "Ready to proceed to Phase 2: Chezmoi Migration"
        debug_trace "← Exiting: main (success)"
        return 0
    else
        log_error "❌ Some validations failed. Please address the issues before proceeding."
        debug_trace "← Exiting: main (failure)"
        return 1
    fi
}

# Handle script interruption
trap 'log_error "Verification script interrupted"; exit 1' INT TERM

# Parse arguments and run main function
parse_arguments "$@"
main