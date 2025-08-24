#!/bin/zsh
#
# macOS System and Environment Setup (macSES) Bootstrap Script
# 
# This script provides a one-command installation for a complete macOS development environment.
# Similar to Claude Code's native binary installation approach.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/bootstrap/setup.core.sh | zsh
#
# Phase 1: Bootstrap Foundation
# - Install Xcode CLI Tools
# - Install Homebrew
# - Clone dotfiles repository with chezmoi integration
# - Set up basic environment
#

set -euo pipefail  # Exit on any error, undefined variable, or pipe failure

# Configuration and Common Library
readonly SCRIPT_DIR="$(cd "${0:A:h}" && pwd)"

# Try to source common library after repository is available
# For bootstrap script, we'll need to handle the case where common.sh might not exist yet
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
    init_logging "setup.core"
    setup_error_trap "setup.core"
else
    # Fallback logging for initial bootstrap (before repo is cloned)
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

# Main installation function
main() {
    log "🚀 Starting macOS System and Environment Setup (macSES)"
    log "📋 Phase 1: Bootstrap Foundation"
    echo ""
    
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE"
    
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
    
    # Step 4: Clone repository
    ((++current_step))
    show_progress $current_step $total_steps "Cloning repository..."
    clone_repository
    
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
}

install_xcode_cli_tools() {
    if xcode-select --print-path &> /dev/null; then
        log_success "Xcode CLI Tools already installed"
        return 0
    fi
    
    log "Installing Xcode Command Line Tools..."
    
    # Trigger the installation
    xcode-select --install &> /dev/null || true
    
    # Wait for installation to complete
    log "Waiting for Xcode CLI Tools installation to complete..."
    log "⏳ This may take several minutes and require user interaction..."
    
    until xcode-select --print-path &> /dev/null; do
        sleep 5
    done
    
    log_success "Xcode CLI Tools installed successfully"
}

install_homebrew() {
    if command -v brew &> /dev/null; then
        log_success "Homebrew already installed"
        return 0
    fi
    
    log "Installing Homebrew..."
    
    # Install Homebrew using the official installer
    /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        log_error "Failed to install Homebrew"
        exit 1
    }
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    log_success "Homebrew installed successfully"
}

setup_directories() {
    log "Setting up directory structure..."
    
    # Create Git directory if it doesn't exist
    mkdir -p "$HOME/Git"
    
    log_success "Directory structure created"
}

clone_repository() {
    if [ -d "$REPO_DIR" ]; then
        log_warning "Repository already exists at $REPO_DIR"
        log "Updating existing repository..."
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
        git clone "$REPO_URL" "$REPO_DIR" || {
            log_error "Failed to clone repository"
            exit 1
        }
    fi
    
    log_success "Repository ready at $REPO_DIR"
}

run_validation() {
    log "Running Phase 1 validation..."
    
    # Check if validation script exists and run it
    if [ -f "$REPO_DIR/bootstrap/verify.setup.sh" ]; then
        zsh "$REPO_DIR/bootstrap/verify.setup.sh" || {
            log_error "Validation failed"
            exit 1
        }
    else
        # Basic validation if script doesn't exist yet
        log "Running basic validation checks..."
        
        # Check Xcode CLI Tools
        if ! xcode-select --print-path &> /dev/null; then
            log_error "Xcode CLI Tools validation failed"
            exit 1
        fi
        
        # Check Homebrew
        if ! command -v brew &> /dev/null; then
            log_error "Homebrew validation failed"
            exit 1
        fi
        
        # Check repository
        if [ ! -d "$REPO_DIR/.git" ]; then
            log_error "Repository validation failed"
            exit 1
        fi
        
        log_success "Basic validation passed"
    fi
    
    log_success "Phase 1 validation completed"
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"