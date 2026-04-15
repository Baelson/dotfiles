#!/bin/zsh
#
# One-Line Installer for macOS Development Environment
# ====================================================
#
# This script provides a modern chezmoi-native bootstrap experience that automatically
# configures a complete macOS development environment with dotfiles, packages, and applications.
#
# Architecture:
# This installer leverages chezmoi's native remote installation capability combined with
# dynamic environment detection and templated configuration management.
#
# References:
# - chezmoi remote install: https://www.chezmoi.io/install/#one-line-binary-install
# - chezmoi init command: https://www.chezmoi.io/reference/commands/init/
# - Template-driven setup: https://www.chezmoi.io/user-guide/templating/
#
# Usage Examples:
#   # Standard installation (interactive prompts)
#   curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/setup.sh | zsh
#   ./setup.sh
#
#   # Preview operations without making changes
#   ./setup.sh --dry-run
#
#   # Detailed debugging with variable inspection
#   ./setup.sh --debug-verbose
#
#   # Control flow tracing for troubleshooting
#   ./setup.sh --debug-trace
#
#   # Show help information
#   ./setup.sh --help
#
#   # Environment-specific installations
#   EPHEMERAL=1 ./setup.sh --dry-run
#   HEADLESS=1 ./setup.sh --debug-verbose
#
#   # Combined options
#   ./setup.sh --dry-run --debug-verbose
#   EPHEMERAL=1 HEADLESS=1 ./setup.sh --debug-trace
#
# Command-line Options:
#   --dry-run         Preview operations without making any system changes
#   --debug-verbose   Show detailed execution logging with variable inspection
#   --debug-trace     Show function-level execution tracing
#   --help           Display comprehensive usage information
#
# Environment Variables:
# - EPHEMERAL: Set to any non-empty value for temporary/borrowed machines
# - HEADLESS: Set to any non-empty value for servers/SSH-only systems
# - ASK: Set to any non-empty value to force interactive prompts
#

set -euo pipefail

# Configuration
readonly REPO_OWNER="Baelson"
readonly REPO_NAME="dotfiles"
readonly REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

# Global execution flags
DRY_RUN=false
DEBUG_VERBOSE=false
DEBUG_TRACE=false
SHOW_HELP=false

# Environment variables for customization
EPHEMERAL="${EPHEMERAL:-}"
HEADLESS="${HEADLESS:-}"
ASK="${ASK:-}"

# Logging functions
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_error() {
    echo "❌ Error: $1" >&2
}

log_warning() {
    echo "⚠️  Warning: $1" >&2
}

debug_trace() {
    if [[ "${DEBUG_TRACE}" == "true" ]]; then
        echo "[TRACE] $1" >&2
    fi
}

debug_verbose() {
    if [[ "${DEBUG_VERBOSE}" == "true" ]]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Show comprehensive help information
show_help() {
    cat << 'EOF'
macOS Development Environment Setup (macSES)
============================================

Transform a fresh macOS installation into a fully configured development environment
with a single command using modern chezmoi-native architecture.

USAGE:
    setup.sh [OPTIONS]
    curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/setup.sh | zsh

OPTIONS:
    --dry-run           Preview all operations without making any system changes
                        Shows what would be executed including chezmoi commands

    --debug-verbose     Enable detailed execution logging with variable inspection
                        Shows command construction, environment variables, and execution steps

    --debug-trace       Enable function-level execution tracing
                        Shows function entry/exit and control flow

    --help              Display this comprehensive help information

ENVIRONMENT VARIABLES:
    EPHEMERAL=1        Configure for temporary/borrowed machines (minimal packages)
    HEADLESS=1         Configure for servers/SSH-only systems (no desktop apps)
    ASK=1              Force interactive prompts even in non-interactive environments

EXAMPLES:
    # Standard installation
    ./setup.sh

    # Preview what would be installed without making changes
    ./setup.sh --dry-run

    # Troubleshoot issues with detailed logging
    ./setup.sh --debug-verbose

    # Debug complex execution flows
    ./setup.sh --debug-trace

    # Ephemeral environment preview
    EPHEMERAL=1 ./setup.sh --dry-run

    # Headless server with verbose debugging
    HEADLESS=1 ./setup.sh --debug-verbose

    # Combined debugging modes
    ./setup.sh --dry-run --debug-verbose --debug-trace

WHAT THIS INSTALLS:
    ✅ Xcode CLI Tools (if needed)
    ✅ chezmoi configuration management tool
    ✅ 70+ packages via Homebrew (CLI tools, desktop apps, Mac App Store)
    ✅ Shell environment (Zsh + Oh My Zsh + Powerlevel10k)
    ✅ Dotfiles and application preferences
    ✅ Encrypted secrets management

REQUIREMENTS:
    - macOS 12+ with internet connection and admin privileges
    - No existing dependencies required (all prerequisites installed automatically)

TROUBLESHOOTING:
    If you encounter issues:
    1. Run with --debug-verbose to see detailed execution information
    2. Run with --dry-run to preview operations without system changes
    3. Check network connectivity and administrative privileges
    4. Review error messages for specific recovery suggestions

For more information, visit: https://github.com/Baelson/dotfiles
EOF
}

# Parse command-line arguments
parse_arguments() {
    debug_trace "parse_arguments: processing $# arguments: $*"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                debug_verbose "parse_arguments: enabled dry-run mode"
                shift
                ;;
            --debug-verbose)
                DEBUG_VERBOSE=true
                debug_verbose "parse_arguments: enabled debug verbose mode"
                shift
                ;;
            --debug-trace)
                DEBUG_TRACE=true
                debug_trace "parse_arguments: enabled debug trace mode"
                shift
                ;;
            --help|-h)
                SHOW_HELP=true
                shift
                ;;
            --*)
                log_error "Unknown option: $1"
                echo ""
                echo "Available options: --dry-run, --debug-verbose, --debug-trace, --help"
                echo "Run './setup.sh --help' for comprehensive usage information."
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                echo ""
                echo "This script does not accept positional arguments."
                echo "Run './setup.sh --help' for comprehensive usage information."
                exit 1
                ;;
        esac
    done

    debug_verbose "parse_arguments: DRY_RUN=${DRY_RUN}, DEBUG_VERBOSE=${DEBUG_VERBOSE}, DEBUG_TRACE=${DEBUG_TRACE}"
}

main() {
    debug_trace "main: starting with arguments: $*"

    # Parse command-line arguments first
    parse_arguments "$@"

    # Show help if requested
    if [[ "${SHOW_HELP}" == "true" ]]; then
        show_help
        exit 0
    fi

    # Display mode information
    echo "🚀 Starting macOS Development Environment Setup..."
    echo "📍 Repository: ${REPO_OWNER}/${REPO_NAME}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "🔍 DRY RUN MODE: No system changes will be made"
    fi

    if [[ "${DEBUG_VERBOSE}" == "true" ]]; then
        echo "🐛 DEBUG VERBOSE: Detailed execution logging enabled"
    fi

    if [[ "${DEBUG_TRACE}" == "true" ]]; then
        echo "🔬 DEBUG TRACE: Function-level tracing enabled"
    fi

    echo ""

    # Execute main setup flow
    debug_trace "main: executing setup flow"
    check_prerequisites
    install_chezmoi_if_needed
    run_chezmoi_init

    echo ""
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "🔍 DRY RUN completed successfully!"
        echo "💡 Remove --dry-run flag to perform actual installation"
    else
        echo "🎉 Setup completed successfully!"
        echo "💡 Run 'chezmoi edit' to modify configurations"
        echo "💡 Run 'chezmoi apply --dry-run' to preview changes"
        echo "💡 Run 'chezmoi apply' to apply pending changes"
    fi
}

check_prerequisites() {
    debug_trace "check_prerequisites: starting prerequisite checks"
    echo "🔍 Checking prerequisites..."

    # Check if we're on macOS
    debug_verbose "check_prerequisites: checking operating system (OSTYPE=${OSTYPE})"
    if [[ "${OSTYPE}" != "darwin"* ]]; then
        log_error "This installer is designed for macOS only"
        echo ""
        echo "🔧 Recovery suggestions:"
        echo "   For other platforms, use chezmoi directly:"
        echo "   sh -c \"\$(curl -fsLS get.chezmoi.io)\" -- init ${REPO_OWNER} --apply"
        exit 1
    fi
    debug_verbose "check_prerequisites: macOS detected successfully"

    # Check if git is available (needed for chezmoi)
    debug_verbose "check_prerequisites: checking for git availability"
    if ! command -v git &> /dev/null; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            echo "🔍 [DRY RUN] Would install Xcode CLI Tools (git not found)"
        else
            echo "📱 Git not found. Installing Xcode CLI Tools..."
            debug_verbose "check_prerequisites: executing xcode-select --install"
            xcode-select --install

            # Wait for installation
            until command -v git &> /dev/null; do
                echo "⏳ Waiting for Xcode CLI Tools installation..."
                debug_verbose "check_prerequisites: still waiting for git to become available"
                sleep 5
            done
            log_success "Xcode CLI Tools installed"
        fi
    else
        debug_verbose "check_prerequisites: git found at $(which git)"
    fi

    log_success "Prerequisites satisfied"
    debug_trace "check_prerequisites: completed successfully"
}

install_chezmoi_if_needed() {
    debug_trace "install_chezmoi_if_needed: checking chezmoi installation status"

    if command -v chezmoi &> /dev/null; then
        local chezmoi_version
        chezmoi_version=$(chezmoi --version | head -1)
        log_success "chezmoi already installed: ${chezmoi_version}"
        debug_verbose "install_chezmoi_if_needed: found chezmoi at $(which chezmoi)"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "🔍 [DRY RUN] Would install chezmoi using official installer:"
        echo "    sh -c \"\$(curl -fsLS get.chezmoi.io)\""
        echo "    export PATH=\"\$HOME/bin:\$PATH\""
        return 0
    fi

    echo "📦 Installing chezmoi..."
    debug_verbose "install_chezmoi_if_needed: executing chezmoi installer"

    # Use chezmoi's official installer
    sh -c "$(curl -fsLS get.chezmoi.io)"

    # Add to PATH for current session
    export PATH="${HOME}/bin:${PATH}"
    debug_verbose "install_chezmoi_if_needed: updated PATH to include \$HOME/bin"

    if command -v chezmoi &> /dev/null; then
        local chezmoi_version
        chezmoi_version=$(chezmoi --version | head -1)
        log_success "chezmoi installed successfully: ${chezmoi_version}"
        debug_verbose "install_chezmoi_if_needed: chezmoi installed at $(which chezmoi)"
    else
        log_error "chezmoi installation failed"
        echo ""
        echo "🔧 Recovery suggestions:"
        echo "   1. Check network connectivity"
        echo "   2. Verify you have write permissions to \$HOME/bin"
        echo "   3. Try installing manually: https://www.chezmoi.io/install/"
        echo "   4. Run with --debug-verbose for more details"
        exit 1
    fi

    debug_trace "install_chezmoi_if_needed: completed successfully"
}

run_chezmoi_init() {
    debug_trace "run_chezmoi_init: starting chezmoi initialization"
    echo "🏠 Initializing dotfiles with chezmoi..."

    # Build chezmoi init command with environment-specific options
    local -a chezmoi_args=(
        "--verbose"
    )

    # Add --apply only if not in dry-run mode
    if [[ "${DRY_RUN}" == "true" ]]; then
        chezmoi_args+=("--dry-run")
        debug_verbose "run_chezmoi_init: added --dry-run to chezmoi command"
    else
        chezmoi_args+=("--apply")
        debug_verbose "run_chezmoi_init: added --apply to chezmoi command"
    fi

    # Add data for template processing
    # Add data for template processing
    debug_verbose "run_chezmoi_init: processing environment variables for template data"

    local template_data=""

    # Use provided values or defaults for ephemeral
    local json_ephemeral="false"
    if [[ -n "${EPHEMERAL:-}" ]] && [[ "${EPHEMERAL}" =~ ^(true|1|yes)$ ]]; then
         json_ephemeral="true"
    fi

    # Use provided values or defaults for headless
    local json_headless="false"
    if [[ -n "${HEADLESS:-}" ]] && [[ "${HEADLESS}" =~ ^(true|1|yes)$ ]]; then
        json_headless="true"
    fi

    local template_data="{\"ephemeral\": ${json_ephemeral}, \"headless\": ${json_headless}}"

    # Append data arg if not empty
    if [[ -n "${template_data}" ]]; then
        # CRITICAL: Use --override-data to inject values. --data is a boolean flag in init!
        chezmoi_args+=("--override-data" "${template_data}")
        debug_verbose "run_chezmoi_init: added template data block"
    fi

    # Interactive mode allows for prompts
    if [[ -z "${ASK}" ]] && [[ -t 0 ]]; then
        echo "💬 Running in interactive mode (set ASK=1 to force prompts)"
        debug_verbose "run_chezmoi_init: interactive mode detected (stdin is TTY)"
    else
        debug_verbose "run_chezmoi_init: non-interactive mode (ASK=${ASK}, stdin TTY check: $([[ -t 0 ]] && echo "true" || echo "false"))"
    fi

    # Initialize chezmoi with the repository
    local cmd_display="chezmoi init ${chezmoi_args[*]} ${DOTFILES_REPO_URL:-${REPO_OWNER}}"
    echo "🔧 Running: ${cmd_display}"
    debug_verbose "run_chezmoi_init: executing chezmoi command with args: ${chezmoi_args[*]}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "🔍 [DRY RUN] Would execute: ${cmd_display}"
        echo "🔍 [DRY RUN] This would initialize chezmoi with your dotfiles repository"
        echo "🔍 [DRY RUN] Template data: ephemeral=${EPHEMERAL:-false}, headless=${HEADLESS:-false}"
    else
        debug_trace "run_chezmoi_init: executing chezmoi init command"
        # CRITICAL: Allow tests to use local repo path via DOTFILES_REPO_URL
        if [[ -n "${DOTFILES_REPO_URL:-}" ]]; then
            chezmoi init "${chezmoi_args[@]}" "${DOTFILES_REPO_URL}"
        else
            chezmoi init "${chezmoi_args[@]}" "${REPO_OWNER}"
        fi
    fi

    debug_trace "run_chezmoi_init: completed successfully"
}

# Enhanced error handling with recovery suggestions
error_handler() {
    local exit_code=$?
    local line_no=$1

    log_error "Script failed at line ${line_no} with exit code ${exit_code}"
    echo ""
    echo "🔧 Recovery suggestions:"
    echo "   1. Run with --debug-verbose to see detailed execution information"
    echo "   2. Run with --dry-run to preview operations without making changes"
    echo "   3. Check network connectivity and administrative privileges"
    echo "   4. Review the error message above for specific guidance"
    echo ""
    echo "For more help, visit: https://github.com/Baelson/dotfiles"

    exit ${exit_code}
}

# Set up error handling
trap 'error_handler ${LINENO}' ERR
trap 'echo "❌ Setup interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"
