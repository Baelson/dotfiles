#!/usr/bin/env bash
#
# Dotfiles Health Check Script
#
# This script performs a comprehensive health check of the dotfiles system
# to ensure all components are properly installed and configured.
#
# Usage: ./scripts/tools/health-check.sh [OPTIONS]
#
# Options:
#   -q, --quick      Run only critical checks (default)
#   -f, --full       Run comprehensive checks including optional components
#   -x, --fix        Attempt to fix common issues automatically
#   -h, --help       Display this help message
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
CHEZMOI_SOURCE_DIR="${DOTFILES_ROOT}/home"
LIFECYCLE_DIR="${CHEZMOI_SOURCE_DIR}/.chezmoiscripts/darwin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health check counters
checks_passed=0
checks_failed=0
checks_warning=0

# Options
QUICK_MODE=true
FULL_MODE=false
AUTO_FIX=false

main() {
    parse_arguments "$@"

    echo "Dotfiles Health Check"
    echo "========================"
    echo ""

    # Change to dotfiles root
    cd "${DOTFILES_ROOT}" || {
        log_error "Cannot change to dotfiles root: ${DOTFILES_ROOT}"
        exit 1
    }

    # Run health checks
    check_critical_commands
    check_development_tools
    check_repository_structure
    check_local_workflow_scripts
    check_setup_script_modes
    check_ssh_configuration
    check_chezmoi_configuration
    check_shell_environment
    check_package_management

    if [[ "${FULL_MODE}" == "true" ]]; then
        check_application_configurations
        check_recent_test_results
    fi

    # Summary
    echo "Health Check Summary:"
    echo "   Passed: ${checks_passed} checks"
    echo "   Warnings: ${checks_warning} checks"
    echo "   Failed: ${checks_failed} checks"
    echo ""

    if [[ ${checks_failed} -eq 0 ]]; then
        if [[ ${checks_warning} -eq 0 ]]; then
            log_success "All health checks passed. System is healthy."
            exit 0
        else
            log_warning "System is mostly healthy with ${checks_warning} warning(s)."
            exit 0
        fi
    else
        log_error "Health check failed with ${checks_failed} error(s)."
        echo ""
        echo "Next steps:"
        echo "   1. Review the failed checks above"
        echo "   2. Run with --fix to attempt automatic fixes"
        echo "   3. Run with --full for comprehensive diagnostics"
        echo "   4. Check docs/ for troubleshooting"
        exit 1
    fi
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((++checks_passed))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((++checks_failed))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((++checks_warning))
}

# Health check functions
check_critical_commands() {
    log_info "Checking critical commands..."

    local critical_commands=("curl" "git" "zsh" "bash")
    for cmd in "${critical_commands[@]}"; do
        if command -v "${cmd}" &> /dev/null; then
            log_success "${cmd} is available"
        else
            log_error "${cmd} is not available"
        fi
    done
    echo ""
}

check_development_tools() {
    log_info "Checking development tools..."

    # Xcode CLI Tools
    if xcode-select --print-path &> /dev/null; then
        log_success "Xcode CLI Tools installed"
    else
        log_error "Xcode CLI Tools not installed"
        if [[ "${AUTO_FIX}" == "true" ]]; then
            log_info "Attempting to install Xcode CLI Tools..."
            xcode-select --install || log_error "Failed to trigger Xcode CLI Tools installation"
        fi
    fi

    # Homebrew
    if command -v brew &> /dev/null; then
        log_success "Homebrew installed"
        if brew doctor &> /dev/null; then
            log_success "Homebrew is healthy"
        else
            log_warning "Homebrew has issues (run 'brew doctor' for details)"
        fi
    else
        log_error "Homebrew not installed"
    fi
    echo ""
}

check_repository_structure() {
    log_info "Checking repository structure..."

    local required_files=(
        "${DOTFILES_ROOT}/.git"
        "${DOTFILES_ROOT}/README.md"
        "${DOTFILES_ROOT}/setup.sh"
        "${DOTFILES_ROOT}/tests/infrastructure/verify-manifest.txt"
        "${CHEZMOI_SOURCE_DIR}/.chezmoi.toml.tmpl"
        "${CHEZMOI_SOURCE_DIR}/.chezmoiexternal.toml"
        "${CHEZMOI_SOURCE_DIR}/Brewfile.tmpl"
        "${LIFECYCLE_DIR}/run_once_before_install-homebrew.sh"
        "${LIFECYCLE_DIR}/run_onchange_after_install-packages.sh.tmpl"
    )

    for file in "${required_files[@]}"; do
        if [[ -e "${file}" ]]; then
            log_success "$(basename "${file}") exists"
        else
            log_error "$(basename "${file}") missing"
        fi
    done
    echo ""
}

check_local_workflow_scripts() {
    log_info "Checking local workflow scripts..."

    local workflow_scripts=(
        "${DOTFILES_ROOT}/scripts/test/test.sh"
        "${DOTFILES_ROOT}/scripts/test/run-critical-tests.sh"
        "${DOTFILES_ROOT}/scripts/test/validate-test-setup.sh"
        "${DOTFILES_ROOT}/scripts/tools/performance-check.sh"
    )
    # vmctl.sh / vm-matrix.sh / init-matrix.sh removed in ISSUE-021;
    # replacement run-e2e.sh lands via Phase 5x feature-branch merge.

    for script in "${workflow_scripts[@]}"; do
        if [[ -x "${script}" ]]; then
            log_success "$(basename "${script}") is executable"
        else
            log_error "$(basename "${script}") is missing or not executable"
        fi
    done
    echo ""
}

check_setup_script_modes() {
    log_info "Checking setup.sh capabilities..."

    if [[ -x "${DOTFILES_ROOT}/setup.sh" ]]; then
        if "${DOTFILES_ROOT}/setup.sh" --help >/dev/null 2>&1; then
            log_success "setup.sh --help works"
        else
            log_error "setup.sh --help failed"
        fi

        if "${DOTFILES_ROOT}/setup.sh" --dry-run >/dev/null 2>&1; then
            log_success "setup.sh --dry-run works"
        else
            log_error "setup.sh --dry-run failed"
        fi
    else
        log_error "setup.sh missing or not executable"
    fi
    echo ""
}

check_ssh_configuration() {
    log_info "Checking SSH configuration..."

    # Check for SSH keys
    local ssh_keys_found=false
    for key_type in rsa ed25519; do
        if [[ -f "${HOME}/.ssh/id_${key_type}" ]]; then
            log_success "SSH ${key_type} key exists"
            ssh_keys_found=true
        fi
    done

    if [[ "${ssh_keys_found}" == "false" ]]; then
        log_warning "No SSH keys found"
    fi

    # Check SSH config
    if [[ -f "${HOME}/.ssh/config" ]]; then
        log_success "SSH config exists"
    else
        log_warning "SSH config not found"
    fi
    echo ""
}

check_chezmoi_configuration() {
    log_info "Checking chezmoi configuration..."

    if command -v chezmoi &> /dev/null; then
        log_success "Chezmoi installed"

        if [[ -f "${CHEZMOI_SOURCE_DIR}/.chezmoiexternal.toml" ]]; then
            log_success "Chezmoi source directory configured"
        else
            log_error "Chezmoi source directory not configured"
        fi

        # Check chezmoi status (skip in CI)
        if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
            if chezmoi doctor &> /dev/null; then
                log_success "Chezmoi configuration is healthy"
            else
                log_warning "Chezmoi has configuration issues"
            fi
        fi
    else
        log_error "Chezmoi not installed"
    fi
    echo ""
}

check_shell_environment() {
    log_info "Checking shell environment..."

    # Check current shell
    if [[ "${SHELL}" == *"zsh"* ]]; then
        log_success "Zsh is the default shell"
    else
        log_warning "Default shell is not Zsh (current: ${SHELL})"
    fi

    # Check Oh My Zsh
    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        log_success "Oh My Zsh installed"
    else
        log_warning "Oh My Zsh not installed"
    fi

    # Check Antigen
    if [[ -d "${HOME}/.local/share/antigen" ]]; then
        log_success "Antigen installed"
    else
        log_warning "Antigen not installed"
    fi

    # Check Powerlevel10k
    if [[ -f "${HOME}/.p10k.zsh" ]]; then
        log_success "Powerlevel10k configured"
    else
        log_warning "Powerlevel10k not configured"
    fi
    echo ""
}

check_package_management() {
    log_info "Checking package management..."

    if command -v brew &> /dev/null; then
        if [[ -f "${CHEZMOI_SOURCE_DIR}/Brewfile.tmpl" ]]; then
            log_success "Chezmoi Brewfile template present"
        else
            log_error "Chezmoi Brewfile template missing"
        fi

        if [[ -f "${HOME}/Brewfile" ]]; then
            log_success "Materialized \$HOME/Brewfile present"
        else
            log_warning "\$HOME/Brewfile not present yet (run chezmoi apply to materialize)"
        fi
    else
        log_error "Homebrew not available for package checking"
    fi
    echo ""
}

check_recent_test_results() {
    log_info "Running quick verification tests..."

    if "${DOTFILES_ROOT}/scripts/test/test.sh" --quick >/dev/null 2>&1; then
        log_success "Quick test suite passed"
    else
        log_error "Quick test suite failed"
    fi
    echo ""
}

check_application_configurations() {
    log_info "Checking application configurations..."

    # VS Code
    if [[ -d "${HOME}/Library/Application Support/Code/User" ]]; then
        log_success "VS Code configuration directory exists"
    else
        log_warning "VS Code configuration directory not found"
    fi

    # Cursor
    if [[ -d "${HOME}/Library/Application Support/Cursor/User" ]]; then
        log_success "Cursor configuration directory exists"
    else
        log_warning "Cursor configuration directory not found"
    fi

    # Docker
    if command -v docker &> /dev/null; then
        log_success "Docker installed"
    else
        log_warning "Docker not installed"
    fi

    echo ""
}

show_help() {
    cat << EOF
Dotfiles Health Check Script

Usage: $0 [OPTIONS]

Options:
  -q, --quick      Run only critical checks (default)
  -f, --full       Run comprehensive checks including optional components
  -x, --fix        Attempt to fix common issues automatically
  -h, --help       Display this help message

Examples:
  $0                    # Run quick health check
  $0 --full             # Run comprehensive health check
  $0 --fix              # Run quick check with auto-fix
  $0 --full --fix       # Run comprehensive check with auto-fix

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quick)
                QUICK_MODE=true
                FULL_MODE=false
                shift
                ;;
            -f|--full)
                FULL_MODE=true
                QUICK_MODE=false
                shift
                ;;
            -x|--fix)
                AUTO_FIX=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

main "$@"
