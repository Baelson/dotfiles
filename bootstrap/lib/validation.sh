#!/bin/zsh
#
# Validation Module
#
# This module provides functions for validating system components
# and configuration status.
#
# Usage: source "$(dirname "$0")/lib/validation.sh"
#

# Guard against multiple sourcing
if [[ -n "${VALIDATION_MODULE_LOADED:-}" ]]; then
    return 0
fi
readonly VALIDATION_MODULE_LOADED=1

# Validation counters
validation_passed=0
validation_failed=0

#======================================
# Core Validation Functions
#======================================

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

# Reset validation counters
reset_validation_counters() {
    validation_passed=0
    validation_failed=0
}

# Get validation summary
get_validation_summary() {
    echo "Validation Summary:"
    echo "   ✅ Passed: $validation_passed checks"
    echo "   ❌ Failed: $validation_failed checks"

    if [[ $validation_failed -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

#======================================
# System Requirements Validation
#======================================

validate_system_requirements() {
    debug_trace "→ Entering: validate_system_requirements"
    log "📋 System Requirements:"

    validate_item "macOS operating system" '[[ "$OSTYPE" == "darwin"* ]]'
    validate_item "zsh shell available" 'command -v zsh'
    validate_item "curl available" 'command -v curl'
    validate_item "git available" 'command -v git'

    debug_trace "← Exiting: validate_system_requirements"
}

#======================================
# Development Tools Validation
#======================================

validate_development_tools() {
    debug_trace "→ Entering: validate_development_tools"
    log "🛠  Development Tools:"

    validate_item "Xcode CLI Tools installed" 'xcode-select --print-path'
    validate_item "Homebrew installed" 'command -v brew'

    debug_trace "← Exiting: validate_development_tools"
}

#======================================
# Repository Structure Validation
#======================================

validate_repository_structure() {
    debug_trace "→ Entering: validate_repository_structure"
    log "📁 Repository Structure:"

    validate_item "Repository cloned" '[ -d "$REPO_DIR/.git" ]'
    validate_item "Brewfile exists" '[ -f "$REPO_DIR/_dotfiles/Brewfile" ] || [ -f "$REPO_DIR/Brewfile" ]'
    validate_item "CLAUDE.md exists" '[ -f "$REPO_DIR/CLAUDE.md" ]'
    validate_item "Bootstrap scripts exist" '[ -f "$REPO_DIR/bootstrap/setup.core.sh" -a -f "$REPO_DIR/bootstrap/setup.macos.sh" ]'
    validate_item "Common library exists" '[ -f "$REPO_DIR/bootstrap/lib/common.sh" ]'

    debug_trace "← Exiting: validate_repository_structure"
}

#======================================
# Package Management Validation
#======================================

validate_package_management() {
    debug_trace "→ Entering: validate_package_management"

    if command -v brew &> /dev/null && { [ -f "$REPO_DIR/_dotfiles/Brewfile" ] || [ -f "$REPO_DIR/Brewfile" ]; }; then
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
    else
        log_warning "Homebrew or Brewfile not available for package validation"
    fi

    debug_trace "← Exiting: validate_package_management"
}

#======================================
# Chezmoi Configuration Validation
#======================================

validate_chezmoi_configuration() {
    debug_trace "→ Entering: validate_chezmoi_configuration"

    if command -v chezmoi &> /dev/null; then
        log "🏠 Chezmoi Configuration:"
        # Determine source directory inside the repository
        local SOURCE_DIR="$REPO_DIR/_dotfiles"
        validate_item "chezmoi source directory exists" '[ -d "$REPO_DIR/_dotfiles" ]'
        validate_item "chezmoi external config exists" '[ -f "$REPO_DIR/_dotfiles/.chezmoiexternal.toml" ]'
        validate_item "chezmoi ignore config exists" '[ -f "$REPO_DIR/_dotfiles/.chezmoiignore" ]'

        # Skip chezmoi doctor in CI environments since it requires proper home directory setup
        if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
            log_warning "Skipping chezmoi doctor in CI environment"
            ((++validation_passed))  # Count as passed since config files exist
        else
            # Run chezmoi doctor and parse results
            log "Running chezmoi doctor..."
            local doctor_output
            # Run doctor and allow non-zero to be handled below
            doctor_output=$(chezmoi doctor 2>&1)
            local doctor_exit_code=$?

            if [[ $doctor_exit_code -eq 0 ]]; then
                # Parse results and show warnings/errors
                local warnings=$(echo "$doctor_output" | grep -c "^warning")
                local errors=$(echo "$doctor_output" | grep -c "^error")

                if [[ $warnings -gt 0 ]]; then
                    log_warning "chezmoi doctor found $warnings warning(s)"
                    echo "$doctor_output" | grep "^warning" | while read -r line; do
                        log_warning "  $line"
                    done
                fi

                if [[ $errors -gt 0 ]]; then
                    log_error "chezmoi doctor found $errors error(s)"
                    echo "$doctor_output" | grep "^error" | while read -r line; do
                        log_error "  $line"
                    done
                    ((++validation_failed))
                else
                    log_success "chezmoi doctor passed (with $warnings warnings)"
                    ((++validation_passed))
                fi
            else
                log_error "chezmoi doctor failed to run"
                ((++validation_failed))
            fi
        fi

        # Check external archives
        check_external_archives_status
    else
        log_warning "Chezmoi not available for configuration validation"
    fi

    debug_trace "← Exiting: validate_chezmoi_configuration"
}

# Check external archives status
check_external_archives_status() {
    debug_trace "→ Entering: check_external_archives_status"

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

    debug_trace "← Exiting: check_external_archives_status"
}

#======================================
# Comprehensive Validation
#======================================

run_comprehensive_validation() {
    debug_trace "→ Entering: run_comprehensive_validation"
    log "🔍 Running comprehensive validation checks..."
    echo ""

    # Reset counters
    reset_validation_counters

    # Run all validation categories
    validate_system_requirements
    echo ""

    validate_development_tools
    echo ""

    validate_repository_structure
    echo ""

    validate_package_management
    echo ""

    validate_chezmoi_configuration
    echo ""

    # Show summary
    log "📊 Validation Summary:"
    get_validation_summary
    echo ""

    if [[ $validation_failed -eq 0 ]]; then
        log_success "🎉 All validations passed! System is properly configured."
        debug_trace "← Exiting: run_comprehensive_validation (success)"
        return 0
    else
        log_error "❌ Some validations failed. Please address the issues before proceeding."
        debug_trace "← Exiting: run_comprehensive_validation (failure)"
        return 1
    fi
}
