#!/bin/zsh
#
# Package Management Module
#
# This module provides functions for managing packages through Homebrew
# and Brewfile processing.
#
# Usage: source "$(dirname "$0")/lib/packages.sh"
#

# Guard against multiple sourcing
if [[ -n "${PACKAGES_MODULE_LOADED:-}" ]]; then
    return 0
fi
readonly PACKAGES_MODULE_LOADED=1

#======================================
# Package Management Functions
#======================================

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

# Check Brewfile status
check_brewfile_status() {
    debug_trace "→ Entering: check_brewfile_status"

    if [[ ! -f "$REPO_DIR/Brewfile" ]]; then
        log_error "Brewfile not found in $REPO_DIR"
        return 1
    fi

    debug_verbose "Checking Brewfile status..."
    if brew bundle check --file="$REPO_DIR/Brewfile" &> /dev/null; then
        log_success "All Brewfile packages are installed"
        return 0
    else
        log_warning "Some Brewfile packages are missing"
        return 1
    fi
}

# Get list of missing packages from Brewfile
get_missing_packages() {
    local missing_packages=()

    if [[ ! -f "$REPO_DIR/Brewfile" ]]; then
        log_error "Brewfile not found"
        return 1
    fi

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Extract package name (first word after 'brew' or 'cask')
        if [[ "$line" =~ ^(brew|cask)[[:space:]]+[\'\"]?([^[:space:]\'\"]+) ]]; then
            local package="${BASH_REMATCH[2]}"
            if ! brew list "$package" &> /dev/null; then
                missing_packages+=("$package")
            fi
        fi
    done < "$REPO_DIR/Brewfile"

    # Return the array (caller needs to handle this properly)
    echo "${missing_packages[@]}"
}

# Install specific package
install_package() {
    local package="$1"

    if [[ -z "$package" ]]; then
        log_error "Package name required"
        return 1
    fi

    debug_trace "→ Installing package: $package"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would install package: $package"
        return 0
    fi

    if brew install "$package"; then
        log_success "Package installed: $package"
        return 0
    else
        log_error "Failed to install package: $package"
        return 1
    fi
}

# Check if package is installed
is_package_installed() {
    local package="$1"

    if [[ -z "$package" ]]; then
        return 1
    fi

    if brew list "$package" &> /dev/null; then
        return 0
    else
        return 1
    fi
}
