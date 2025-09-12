#!/bin/zsh
#
# Common Functions and Constants for macSES Bootstrap Scripts
#
# This library provides shared functionality for all bootstrap scripts including:
# - Common constants and configuration
# - Logging functions with consistent formatting
# - Error handling and cleanup
# - Utility functions
#
# Usage: source "$(dirname "$0")/lib/common.sh"
#

# Guard against multiple sourcing
if [[ -n "${COMMON_LOADED:-}" ]]; then
    return 0
fi
readonly COMMON_LOADED=1

# Strict error handling
set -euo pipefail

#======================================
# Constants and Configuration
#======================================

# Project Configuration
# Only set as readonly if not already set (avoids conflicts with main script)
if [[ -z "${REPO_URL:-}" ]]; then
    readonly REPO_URL="https://github.com/Baelson/dotfiles.git"
fi
if [[ -z "${REPO_DIR:-}" ]]; then
    readonly REPO_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Git/dotfiles")"
fi
if [[ -z "${LOG_DIR:-}" ]]; then
    # Default logs under scripts/setup/logs inside the repo
    readonly LOG_DIR="${REPO_DIR:-$PWD}/scripts/setup/logs"
fi

# Color Constants for Output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'  # No Color

#======================================
# Path Resolution Functions
#======================================

# Get the absolute path of the script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[1]:-${0:A:h}}")" && pwd)"
}

# Get the repository root directory


# Generate timestamped log file path
get_log_file() {
    local script_name="${1:-script}"
    local timestamp
    timestamp="$(date +'%Y-%m-%d_%H-%M-%S')"
    echo "$LOG_DIR/${script_name}_${timestamp}.log"
}

#======================================
# Logging Functions
#======================================

# Initialize logging for a script
init_logging() {
    local script_name="$1"
    LOG_FILE="$(get_log_file "$script_name")"
    export LOG_FILE

    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"

    # Create log file
    touch "$LOG_FILE"
}

# Basic log function with timestamp
log() {
    local msg="${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo -e "$msg"
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Success log with checkmark
log_success() {
    local msg="${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
    echo -e "$msg"
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1" >> "$LOG_FILE"
}

# Warning log with warning emoji
log_warning() {
    local msg="${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
    echo -e "$msg"
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1" >> "$LOG_FILE"
}

# Error log with X emoji
log_error() {
    local msg="${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
    echo -e "$msg" >&2
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1" >> "$LOG_FILE"
}

#======================================
# Progress Tracking
#======================================

# Show progress with percentage
show_progress() {
    local current=$1
    local total=$2
    local description="$3"
    local percentage=$((current * 100 / total))

    printf "\n${BLUE}Progress: [%3d%%] %s${NC}\n" "$percentage" "$description"
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

#======================================
# Error Handling
#======================================

# Setup error trap for script
setup_error_trap() {
    local script_name="$1"
    trap "log_error '$script_name interrupted'; exit 1" INT TERM
}

# Check if we're running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS only"
        return 1
    fi
    return 0
}

#======================================
# Debug and Dry-Run Functions
#======================================

# Debug functions with proper set -e handling
debug_trace() {
    if [[ "${DEBUG_TRACE:-false}" == "true" || "${DEBUG_VERBOSE:-false}" == "true" ]]; then
        echo "[TRACE] $1" >&2
    fi
    return 0
}

debug_verbose() {
    if [[ "${DEBUG_VERBOSE:-false}" == "true" ]]; then
        echo "[DEBUG] $1" >&2
    fi
    return 0
}

log_dry_run() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo "[DRY-RUN] $1"
    fi
    return 0
}

# Execute command with dry-run and debug support
run_command() {
    local cmd="$1"
    local description="$2"

    debug_trace "→ Entering: $description"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
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

# Execute command using tool's native dry-run support
run_with_native_dry_run() {
    local tool="$1"
    local dry_run_flag="$2"
    local actual_cmd="$3"
    local description="$4"

    debug_trace "→ Entering: $description"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
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
# Common Argument Parsing Utilities
#======================================

# Standard help text generator
show_standard_help() {
    local script_name="$1"
    local description="$2"
    local usage_line="$3"

    cat << EOF
$script_name

$description

USAGE:
    $usage_line

OPTIONS:
    --dry-run|-n        Preview operations without executing
    --debug-trace|-t    Show control flow and decision points
    --debug-verbose|-v  Show detailed execution including variables
    --help|-h           Display this help message

EXAMPLES:
    $usage_line
    $usage_line --dry-run|-n
    $usage_line --debug-verbose|-v

EOF
}

# Parse standard debug and dry-run arguments
# Usage: parse_standard_arguments "$@"
# This function sets global variables: DRY_RUN, DEBUG_TRACE, DEBUG_VERBOSE
parse_standard_arguments() {
    debug_trace "→ Entering: parse_standard_arguments"
    debug_trace "Current arguments: $*"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                export DRY_RUN=true
                debug_verbose "Set DRY_RUN=true"
                shift
                ;;
            --debug-trace|-t)
                export DEBUG_TRACE=true
                debug_verbose "Set DEBUG_TRACE=true"
                shift
                ;;
            --debug-verbose|-v)
                export DEBUG_VERBOSE=true
                export DEBUG_TRACE=true  # verbose includes trace
                debug_verbose "Set DEBUG_VERBOSE=true, DEBUG_TRACE=true"
                shift
                ;;
            --help|-h)
                # Let calling script handle --help
                shift
                return 1
                ;;
            *)
                # Return unknown argument for calling script to handle
                debug_trace "← Exiting: parse_standard_arguments (unknown: $1)"
                log_error "Unknown option: $1\
                           \nAvailable options: --dry-run|-n, --debug-trace|-t, --debug-verbose|-v, --help|-h"
                return 2
                ;;
        esac
    done

    debug_trace "← Exiting: parse_standard_arguments"
    return 0
}

#======================================
# Performance Timing Functions
#======================================

# Time a command execution and log the duration
time_operation() {
    local description="$1"
    shift
    local start_time
    start_time=$(date +%s)

    debug_trace "→ Starting timed operation: $description"

    # Execute the command
    if "$@"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        debug_verbose "Operation '$description' completed in ${duration}s"
        log_success "✅ $description (${duration}s)"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        debug_verbose "Operation '$description' failed after ${duration}s"
        log_error "❌ $description failed (${duration}s)"
        return 1
    fi
}

# Time a function execution (for internal functions)
time_function() {
    local function_name="$1"
    local start_time
    start_time=$(date +%s)

    debug_trace "→ Starting timed function: $function_name"

    # Call the function (assumes it's defined)
    if "$function_name"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        debug_verbose "Function '$function_name' completed in ${duration}s"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        debug_verbose "Function '$function_name' failed after ${duration}s"
        return 1
    fi
}

# Get current timestamp for performance logging
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Log performance metrics
log_performance() {
    local operation="$1"
    local duration="$2"
    local status="${3:-success}"

    if [[ "$DEBUG_VERBOSE" == "true" ]]; then
        echo "[PERF] $(get_timestamp) | $operation | ${duration}s | $status" >> "${LOG_FILE:-/tmp/dotfiles_performance.log}"
    fi
}

#======================================
# Utility Functions
#======================================

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Run a command and capture its success
run_safe() {
    local description="$1"
    shift

    log "Running: $description"
    if "$@"; then
        log_success "$description completed"
        return 0
    else
        log_error "$description failed"
        return 1
    fi
}

# Ensure directory exists
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_success "Created directory: $dir"
    fi
}

#======================================
# Version Information
#======================================

version() {
    echo "macSES Common Library v1.0.0"
    echo "macOS System and Environment Setup"
}

# Common library loaded - log message will be available after init_logging is called
