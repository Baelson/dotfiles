#!/bin/zsh
#
# Homebrew Installation and Management Module
#
# This module provides functions for installing and managing Homebrew
# on macOS systems, including architecture detection and PATH configuration.
#
# Usage: source "$(dirname "$0")/lib/homebrew.sh"
#

# Guard against multiple sourcing
if [[ -n "${HOMEBREW_MODULE_LOADED:-}" ]]; then
    return 0
fi
readonly HOMEBREW_MODULE_LOADED=1

#======================================
# Homebrew Functions
#======================================

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

    # Configure Homebrew PATH
    configure_homebrew_path

    log_success "Homebrew installed and configured successfully"
    debug_trace "← Exiting: install_homebrew"
}

configure_homebrew_path() {
    debug_trace "→ Entering: configure_homebrew_path"

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

    debug_trace "← Exiting: configure_homebrew_path"
}

# Check if Homebrew is installed and working
check_homebrew() {
    if command -v brew &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Get Homebrew information
get_homebrew_info() {
    if check_homebrew; then
        local brew_path
        brew_path=$(which brew)
        debug_verbose "Homebrew path: $brew_path"

        # Get Homebrew version
        local version
        version=$(brew --version 2>/dev/null | head -1)
        debug_verbose "Homebrew version: $version"

        # Get architecture info
        local arch
        arch=$(brew --prefix 2>/dev/null)
        debug_verbose "Homebrew prefix: $arch"
    else
        debug_verbose "Homebrew not installed"
    fi
}

# Check Homebrew health
check_homebrew_health() {
    if ! check_homebrew; then
        log_error "Homebrew not installed"
        return 1
    fi

    debug_verbose "Running Homebrew doctor check..."
    if brew doctor &> /dev/null; then
        log_success "Homebrew is healthy"
        return 0
    else
        log_warning "Homebrew has issues (run 'brew doctor' for details)"
        return 1
    fi
}
