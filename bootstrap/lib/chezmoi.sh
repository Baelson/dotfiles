#!/bin/zsh
#
# Chezmoi Configuration Management Module
#
# This module provides functions for managing dotfiles configuration
# using Chezmoi.
#
# Usage: source "$(dirname "$0")/lib/chezmoi.sh"
#

# Guard against multiple sourcing
if [[ -n "${CHEZMOI_MODULE_LOADED:-}" ]]; then
    return 0
fi
readonly CHEZMOI_MODULE_LOADED=1

#======================================
# Chezmoi Functions
#======================================

apply_dotfiles_configuration() {
    debug_trace "→ Entering: apply_dotfiles_configuration"
    log "🏠 Applying dotfiles configuration with chezmoi..."

    # Verify chezmoi is available (should be installed from Brewfile)
    if ! command -v chezmoi &> /dev/null; then
        log_error "chezmoi not found in PATH"
        log_error "Please ensure chezmoi was installed from the Brewfile"
        exit 1
    fi

    # Determine and verify chezmoi source directory within the repo
    local CHEZMOI_SOURCE_DIR
    CHEZMOI_SOURCE_DIR="$REPO_DIR/_dotfiles"
    if [[ ! -d "$CHEZMOI_SOURCE_DIR" ]]; then
        log_error "Chezmoi source directory not found: $CHEZMOI_SOURCE_DIR"
        log_error "Ensure your chezmoi-managed files are under _dotfiles/"
        exit 1
    fi
    if [[ ! -f "$CHEZMOI_SOURCE_DIR/.chezmoiexternal.toml" ]]; then
        log_error "Missing .chezmoiexternal.toml in $CHEZMOI_SOURCE_DIR"
        exit 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would apply dotfiles using: chezmoi --source \"$CHEZMOI_SOURCE_DIR\" apply"
        log_dry_run "Would download external archives (antigen, oh-my-zsh, dircolors)"
        log_dry_run "Would replace Mackup symlinks with actual file content"
        debug_trace "← Exiting: apply_dotfiles_configuration (dry-run)"
        return 0
    fi

    # Apply dotfiles configuration
    debug_verbose "Applying dotfiles configuration from source directory"
    log "  → Downloading external archives (antigen, oh-my-zsh, dircolors)..."
    log "  → Replacing Mackup symlinks with actual file content..."
    log "  → Updating application configurations..."

    if ! chezmoi --source "$CHEZMOI_SOURCE_DIR" apply; then
        log_error "Failed to apply dotfiles configuration"
        log_error "You can manually run: chezmoi --source $CHEZMOI_SOURCE_DIR apply"
        exit 1
    fi

    log_success "Dotfiles configuration applied successfully"
    log "  ✅ External archives downloaded and configured"
    log "  ✅ Mackup symlinks replaced with direct file management"
    log "  ✅ All application configurations updated"
    debug_trace "← Exiting: apply_dotfiles_configuration"
}

# Check if chezmoi is installed and working
check_chezmoi() {
    if command -v chezmoi &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check chezmoi configuration health
check_chezmoi_health() {
    if ! check_chezmoi; then
        log_error "Chezmoi not installed"
        return 1
    fi

    # Skip chezmoi doctor in CI environments
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        log_warning "Skipping chezmoi doctor in CI environment"
        return 0
    fi

    debug_verbose "Running chezmoi doctor..."
    local doctor_output
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
            return 1
        else
            log_success "chezmoi doctor passed (with $warnings warnings)"
            return 0
        fi
    else
        log_error "chezmoi doctor failed to run"
        return 1
    fi
}

# Check external archives status
check_external_archives() {
    debug_trace "→ Entering: check_external_archives"

    local archives_ok=true

    # Check antigen
    if [[ -d "$HOME/.local/share/antigen" ]]; then
        log_success "External archive: antigen downloaded"
    else
        log_warning "External archive: antigen not yet downloaded (run chezmoi apply)"
        archives_ok=false
    fi

    # Check oh-my-zsh
    if [[ -d "$HOME/.local/share/oh-my-zsh" ]]; then
        log_success "External archive: oh-my-zsh downloaded"
    else
        log_warning "External archive: oh-my-zsh not yet downloaded (run chezmoi apply)"
        archives_ok=false
    fi

    # Check dircolors
    if [[ -d "$HOME/.local/share/dircolors" ]]; then
        log_success "External archive: dircolors downloaded"
    else
        log_warning "External archive: dircolors not yet downloaded (run chezmoi apply)"
        archives_ok=false
    fi

    debug_trace "← Exiting: check_external_archives"
    return $([ "$archives_ok" == "true" ] && echo 0 || echo 1)
}

# Get chezmoi status information
get_chezmoi_info() {
    if check_chezmoi; then
        local version
        version=$(chezmoi --version 2>/dev/null | head -1)
        debug_verbose "Chezmoi version: $version"

        # Check source directory
        if [[ -f "$REPO_DIR/.chezmoiexternal.toml" ]]; then
            debug_verbose "Chezmoi source directory: $REPO_DIR"
        else
            debug_verbose "Chezmoi source directory not configured"
        fi
    else
        debug_verbose "Chezmoi not installed"
    fi
}
