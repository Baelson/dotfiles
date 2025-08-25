#!/bin/zsh
#
# macOS System and Environment Setup (macSES) Bootstrap Script
#
# This script provides a one-command installation for a complete macOS development environment.
# Similar to Claude Code's native binary installation approach.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/bootstrap/setup.core.sh | zsh
#        ./bootstrap/setup.core.sh [OPTIONS]
#
# Options:
#   --dry-run           Preview operations without executing (uses tools' native dry-run when available)
#   --debug-trace       Show control flow and decision points
#   --debug-verbose     Show detailed execution including variable assignments
#   --help             Display this help message
#
# Phase 1: Bootstrap Foundation
# - Install Xcode CLI Tools
# - Install Homebrew
# - Clone dotfiles repository with chezmoi integration
# - Set up basic environment
#

set -euo pipefail  # Exit on any error, undefined variable, or pipe failure

# Global script flags
DRY_RUN=false
DEBUG_TRACE=false
DEBUG_VERBOSE=false
SCRIPT_RELOCATED=false

# Repository configuration
readonly REPO_URL="https://github.com/Baelson/dotfiles.git"
readonly REPO_DIR="$HOME/Git/dotfiles"

# Configuration and Common Library
readonly SCRIPT_DIR="$(cd "${0:A:h}" && pwd)"

#======================================
# Debug and Logging Functions
#======================================

debug_trace() {
    [[ "$DEBUG_TRACE" == "true" || "$DEBUG_VERBOSE" == "true" ]] && echo "[TRACE] $1" >&2
}

debug_verbose() {
    [[ "$DEBUG_VERBOSE" == "true" ]] && echo "[DEBUG] $1" >&2
}

log_dry_run() {
    [[ "$DRY_RUN" == "true" ]] && echo "[DRY-RUN] $1"
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

#======================================
# Error Handling and Cleanup
#======================================

cleanup() {
    debug_trace "→ Entering: cleanup"
    
    # Add any cleanup tasks here
    # For now, just log the cleanup
    debug_verbose "Performing cleanup tasks"
    
    debug_trace "← Exiting: cleanup"
}

handle_error() {
    local exit_code=$?
    local line_number=$1
    
    debug_trace "→ Entering: handle_error (exit_code: $exit_code, line: $line_number)"
    
    log_error "Script failed at line $line_number with exit code $exit_code"
    log_error "Check the log file for details: ${LOG_FILE:-'(log file not set)'}"
    
    # Provide recovery suggestions
    log_error "Recovery suggestions:"
    log_error "  1. Check network connectivity"
    log_error "  2. Ensure you have sufficient disk space"
    log_error "  3. Try running with --debug-verbose for more details"
    log_error "  4. Check the repository is accessible: https://github.com/Baelson/dotfiles"
    
    cleanup
    debug_trace "← Exiting: handle_error"
    exit $exit_code
}

# Enhanced error trap
setup_error_handling() {
    debug_trace "→ Entering: setup_error_handling"
    
    # Set up error handling
    set -eE  # Exit on error and inherit ERR trap
    
    # Trap errors with line numbers
    trap 'handle_error ${LINENO}' ERR
    trap 'log_error "Script interrupted by user"; cleanup; exit 130' INT
    trap 'log_error "Script terminated"; cleanup; exit 143' TERM
    
    debug_trace "← Exiting: setup_error_handling"
}

# Try to source common library after repository is available
# For bootstrap script, we'll need to handle the case where common.sh might not exist yet
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
    init_logging "setup.core"
    setup_error_trap "setup.core"
else
    # Fallback logging for initial bootstrap (before repo is cloned)
    # Create Git directory if needed
    mkdir -p "$HOME/Git"
    readonly LOG_FILE="$HOME/Git/install_$(date +'%Y-%m-%d_%H-%M-%S').log"

    # Basic colors and logging functions (fallback)
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'

    log() {
        local msg="${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
        echo -e "$msg"
        [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    }

    log_success() {
        local msg="${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
        echo -e "$msg"
        [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1" >> "$LOG_FILE"
    }

    log_warning() {
        local msg="${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
        echo -e "$msg"
        [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1" >> "$LOG_FILE"
    }

    log_error() {
        local msg="${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
        echo -e "$msg" >&2
        [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1" >> "$LOG_FILE"
    }

    show_progress() {
        local current=$1
        local total=$2
        local description=$3
        local percentage=$((current * 100 / total))
        printf "\n\n${BLUE}Progress: [%3d%%] %s${NC}\n" "$percentage" "$description"
        if [ "$current" -eq "$total" ]; then
            echo ""
        fi
    }
fi

#======================================
# Argument Parsing and Help
#======================================

show_help() {
    cat << EOF
macOS System and Environment Setup (macSES) Bootstrap Script

Usage: $0 [OPTIONS]

Options:
  --dry-run           Preview operations without executing (uses tools' native dry-run when available)
  --debug-trace       Show control flow and decision points
  --debug-verbose     Show detailed execution including variable assignments
  --help             Display this help message

Examples:
  $0                    # Full bootstrap
  $0 --dry-run         # Preview what would happen
  $0 --debug-verbose   # Full bootstrap with detailed logging

For more information, see: https://github.com/Baelson/dotfiles
EOF
}

parse_arguments() {
    debug_trace "→ Entering: parse_arguments"
    
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
            --script-relocated)
                SCRIPT_RELOCATED=true
                debug_verbose "Set SCRIPT_RELOCATED=true (internal flag)"
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

#======================================
# Script Relocation Logic
#======================================

verify_repository_files() {
    debug_trace "→ Entering: verify_repository_files"
    
    local required_files=(
        "bootstrap/setup.core.sh"
        "bootstrap/lib/common.sh"
        "Brewfile"
        "CLAUDE.md"
    )
    
    log "🔍 Verifying required repository files..."
    
    for file in "${required_files[@]}"; do
        local file_path="$REPO_DIR/$file"
        debug_verbose "Checking file: $file_path"
        
        if [[ ! -f "$file_path" ]]; then
            log_error "Required file missing: $file"
            log_error "Repository clone may be incomplete or corrupted"
            debug_trace "← Exiting: verify_repository_files (missing file: $file)"
            exit 1
        else
            debug_verbose "✓ File found: $file"
        fi
    done
    
    log_success "All required files verified"
    debug_trace "← Exiting: verify_repository_files"
}

relocate_script_if_needed() {
    debug_trace "→ Entering: relocate_script_if_needed"
    
    # If already relocated, skip
    if [[ "$SCRIPT_RELOCATED" == "true" ]]; then
        debug_trace "Script already relocated, continuing"
        debug_trace "← Exiting: relocate_script_if_needed (already relocated)"
        return 0
    fi
    
    # If we're not running from the expected location, we need to relocate
    local current_dir="$(pwd)"
    debug_verbose "Current directory: $current_dir"
    debug_verbose "Expected repo directory: $REPO_DIR"
    
    if [[ "$current_dir" != "$REPO_DIR" ]] && [[ ! -f "$REPO_DIR/bootstrap/setup.core.sh" ]]; then
        log "📁 Setting up repository directory structure..."
        
        # Create the Git directory if it doesn't exist
        if [[ ! -d "$HOME/Git" ]]; then
            run_command "mkdir -p '$HOME/Git'" "Create Git directory"
        fi
        
        # Clone the repository
        clone_repository
        
        # Verify required files exist
        verify_repository_files
        
        # Relaunch the script from the proper location
        log "🔄 Relaunching script from repository location..."
        
        local script_args=""
        [[ "$DRY_RUN" == "true" ]] && script_args="$script_args --dry-run"
        [[ "$DEBUG_TRACE" == "true" ]] && script_args="$script_args --debug-trace"
        [[ "$DEBUG_VERBOSE" == "true" ]] && script_args="$script_args --debug-verbose"
        script_args="$script_args --script-relocated"
        
        debug_verbose "Relaunching with args: $script_args"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would execute: cd '$REPO_DIR' && ./bootstrap/setup.core.sh $script_args"
            debug_trace "← Exiting: relocate_script_if_needed (dry-run relaunch)"
            return 0
        else
            cd "$REPO_DIR"
            exec ./bootstrap/setup.core.sh $script_args
        fi
    fi
    
    debug_trace "← Exiting: relocate_script_if_needed (no relocation needed)"
}

# Main installation function
main() {
    debug_trace "→ Entering: main"
    
    log "🚀 Starting macOS System and Environment Setup (macSES)"
    log "📋 Phase 1: Bootstrap Foundation"
    [[ "$DRY_RUN" == "true" ]] && log "[DRY-RUN MODE] Preview only - no changes will be made"
    [[ "$DEBUG_TRACE" == "true" ]] && log "[DEBUG] Trace mode enabled"
    [[ "$DEBUG_VERBOSE" == "true" ]] && log "[DEBUG] Verbose mode enabled"
    echo ""

    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi

    # Create log file
    touch "$LOG_FILE"
    
    # Handle script relocation first
    relocate_script_if_needed

    # Phase 1 Steps
    local -r total_steps=5
    local current_step=0

    # Step 1: Check and install Xcode CLI Tools
    ((++current_step))
    show_progress $current_step $total_steps "Installing Xcode CLI Tools..."
    install_xcode_cli_tools

    # Step 2: Check and install Homebrew
    ((++current_step))
    show_progress $current_step $total_steps "Installing Homebrew..."
    install_homebrew

    # Step 3: Create Git directory structure
    ((++current_step))
    show_progress $current_step $total_steps "Setting up directory structure..."
    setup_directories

    # Step 4: Clone repository (only if not already relocated)
    if [[ "$SCRIPT_RELOCATED" != "true" ]]; then
        ((++current_step))
        show_progress $current_step $total_steps "Cloning repository..."
        clone_repository
        verify_repository_files
    else
        ((++current_step))
        show_progress $current_step $total_steps "Repository already available..."
    fi

    # Step 5: Run validation
    ((++current_step))
    show_progress $current_step $total_steps "Running validation..."
    run_validation

    log_success "🎉 Phase 1: Bootstrap Foundation completed successfully!"
    echo ""
    log "📍 Next Steps:"
    log "  1. Phase 2: Run 'cd $REPO_DIR && ./bootstrap/setup.macos.sh' to continue setup"
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

    until xcode-select --print-path &> /dev/null; do
        sleep 5
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
    # single-line CLI: /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    debug_verbose "Installing Homebrew with explicit bash shebang handling"
    /bin/bash -c "$(curl \
        --fail \
        --silent \
        --show-error \
        --location \
        https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        log_error "Failed to install Homebrew"
        exit 1
    }

    # Add Homebrew to PATH based on architecture
    local brew_path
    local shellenv_line
    
    if [[ $(uname -m) == "arm64" ]]; then
        brew_path="/opt/homebrew/bin/brew"
        debug_verbose "Apple Silicon detected, using $brew_path"
    else
        brew_path="/usr/local/bin/brew"
        debug_verbose "Intel Mac detected, using $brew_path"
    fi
    
    shellenv_line="eval \"\$($brew_path shellenv)\""
    
    # Add to .zprofile if not already present
    if ! grep -q "$shellenv_line" "$HOME/.zprofile" 2>/dev/null; then
        echo "$shellenv_line" >> "$HOME/.zprofile"
        debug_verbose "Added Homebrew shellenv to .zprofile"
    fi
    
    # Source shellenv for current session
    eval "$($brew_path shellenv)"
    debug_verbose "Sourced Homebrew shellenv for current session"
    
    # Verify brew is now accessible
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew installation failed - brew command not accessible"
        exit 1
    fi

    log_success "Homebrew installed successfully"
    debug_trace "← Exiting: install_homebrew"
}

setup_directories() {
    debug_trace "→ Entering: setup_directories"
    
    log "Setting up directory structure..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would create: $HOME/Git"
        debug_trace "← Exiting: setup_directories (dry-run)"
        return 0
    fi

    # Create Git directory if it doesn't exist
    debug_verbose "Creating directory: $HOME/Git"
    mkdir -p "$HOME/Git"

    log_success "Directory structure created"
    debug_trace "← Exiting: setup_directories"
}

clone_repository() {
    debug_trace "→ Entering: clone_repository"
    
    if [ -d "$REPO_DIR" ]; then
        log_warning "Repository already exists at $REPO_DIR"
        log "Updating existing repository..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would check for uncommitted changes"
            log_dry_run "Would run: git pull origin main"
            debug_trace "← Exiting: clone_repository (dry-run update)"
            return 0
        fi
        
        cd "$REPO_DIR"

        # Check for uncommitted changes and fail if found
        if ! git diff --quiet || ! git diff --cached --quiet; then
            log_error "Repository has uncommitted changes"
            log_error "Please commit or stash your changes before running this script"
            log_error "You can stash changes with: git stash push -m 'your message'"
            log "\n$(git status)"
            exit 1
        fi

        git pull origin main || {
            log_error "Failed to update repository"
            exit 1
        }
    else
        log "Cloning repository to $REPO_DIR..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would run: git clone $REPO_URL $REPO_DIR"
            debug_trace "← Exiting: clone_repository (dry-run clone)"
            return 0
        fi
        
        # Try SSH first, fallback to HTTPS if it fails
        local ssh_url="git@github.com:Baelson/dotfiles.git"
        debug_verbose "Attempting SSH clone: $ssh_url"
        
        if git clone "$ssh_url" "$REPO_DIR" 2>/dev/null; then
            log_success "Repository cloned via SSH"
        else
            log_warning "SSH clone failed, trying HTTPS..."
            debug_verbose "SSH clone failed, attempting HTTPS: $REPO_URL"
            
            git clone "$REPO_URL" "$REPO_DIR" || {
                log_error "Failed to clone repository via HTTPS"
                log_error "Repository may be private or network issue"
                log_error "If this is a private repository, ensure SSH keys are configured"
                exit 1
            }
            log_success "Repository cloned via HTTPS"
        fi
    fi

    log_success "Repository ready at $REPO_DIR"
    debug_trace "← Exiting: clone_repository"
}

run_validation() {
    debug_trace "→ Entering: run_validation"
    
    log "Running Phase 1 validation..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would run validation script: $REPO_DIR/bootstrap/verify.setup.sh"
        log_dry_run "Would validate: Xcode CLI Tools, Homebrew, Repository"
        debug_trace "← Exiting: run_validation (dry-run)"
        return 0
    fi

    # Check if validation script exists and run it
    if [ -f "$REPO_DIR/bootstrap/verify.setup.sh" ]; then
        debug_verbose "Running validation script: verify.setup.sh"
        zsh "$REPO_DIR/bootstrap/verify.setup.sh" || {
            log_error "Validation failed"
            exit 1
        }
    else
        # Basic validation if script doesn't exist yet
        log "Running basic validation checks..."
        debug_verbose "Validation script not found, running basic checks"

        # Check Xcode CLI Tools
        debug_verbose "Validating Xcode CLI Tools"
        if ! xcode-select --print-path &> /dev/null; then
            log_error "Xcode CLI Tools validation failed"
            exit 1
        fi

        # Check Homebrew
        debug_verbose "Validating Homebrew"
        if ! command -v brew &> /dev/null; then
            log_error "Homebrew validation failed"
            exit 1
        fi

        # Check repository
        debug_verbose "Validating repository"
        if [ ! -d "$REPO_DIR/.git" ]; then
            log_error "Repository validation failed"
            exit 1
        fi

        log_success "Basic validation passed"
    fi

    log_success "Phase 1 validation completed"
    debug_trace "← Exiting: run_validation"
}

# Parse arguments and run main function
parse_arguments "$@"
setup_error_handling
main
