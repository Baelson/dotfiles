#!/usr/bin/env bash
# Run VM controller actions across multiple matrix profiles.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/vm/lib.sh
source "${SCRIPT_DIR}/lib.sh"

ACTION='plan'
MATRIX_FILE="$(vm_default_matrix_file)"
PROFILE_FILTER=''
INCLUDE_DISABLED='false'
DRY_RUN='false'
APPLY_MODE='false'
VERBOSE='false'

main() {
  parse_arguments "$@"
  validate_matrix

  if [[ "$ACTION" == 'doctor' && -z "$PROFILE_FILTER" ]]; then
    run_vmctl_doctor
    return 0
  fi

  run_matrix_action
}

show_help() {
  cat <<'EOF_HELP'
VM matrix orchestrator

Usage:
  scripts/vm/vm-matrix.sh [options]

Options:
  -a, --action ACTION        Action: doctor | plan | create | run-e2e
  -m, --matrix-file FILE     Matrix JSON file
  -p, --profiles CSV         Comma-separated profile names
  -e, --include-disabled     Include disabled profiles
  -n, --dry-run              Print commands without executing them
  -A, --apply                For run-e2e: run full apply (not --dry-run)
  -v, --verbose              Verbose output
  -h, --help                 Show help output

Examples:
  scripts/vm/vm-matrix.sh --action plan
  scripts/vm/vm-matrix.sh --action create --profiles current,beta
  scripts/vm/vm-matrix.sh --action run-e2e --profiles current --apply
EOF_HELP
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--action)
        ACTION="$2"
        shift 2
        ;;
      -m|--matrix-file)
        MATRIX_FILE="$2"
        shift 2
        ;;
      -p|--profiles)
        PROFILE_FILTER="$2"
        shift 2
        ;;
      -e|--include-disabled)
        INCLUDE_DISABLED='true'
        shift
        ;;
      -n|--dry-run)
        DRY_RUN='true'
        shift
        ;;
      -A|--apply)
        APPLY_MODE='true'
        shift
        ;;
      -v|--verbose)
        VERBOSE='true'
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        vm_die "Unknown option: $1"
        ;;
    esac
  done
}

validate_matrix() {
  [[ -f "$MATRIX_FILE" ]] || vm_die "Matrix file not found: ${MATRIX_FILE}"

  if ! vm_matrix_validate_schema "$MATRIX_FILE" >/dev/null; then
    vm_die "Matrix validation failed: ${MATRIX_FILE}"
  fi
}

run_vmctl_doctor() {
  local -a cmd=(
    "${SCRIPT_DIR}/vmctl.sh"
    --action doctor
    --matrix-file "$MATRIX_FILE"
  )

  if [[ "$VERBOSE" == 'true' ]]; then
    cmd+=( --verbose )
  fi

  if [[ "$DRY_RUN" == 'true' ]]; then
    cmd+=( --dry-run )
  fi

  vm_run_or_echo "$DRY_RUN" "${cmd[@]}"
}

collect_profiles() {
  local include_disabled_arg='true'

  if [[ "$INCLUDE_DISABLED" != 'true' ]]; then
    include_disabled_arg='false'
  fi

  if [[ -n "$PROFILE_FILTER" ]]; then
    printf '%s\n' "$PROFILE_FILTER" | tr ',' '\n'
    return 0
  fi

  vm_matrix_profiles "$MATRIX_FILE" "$include_disabled_arg"
}

run_matrix_action() {
  local failures=0
  local profile=''
  local profiles=''

  profiles="$(collect_profiles)"

  while IFS= read -r profile; do
    [[ -n "$profile" ]] || continue

    vm_log_info "Running action '${ACTION}' for profile '${profile}'"

    local -a cmd=(
      "${SCRIPT_DIR}/vmctl.sh"
      --action "$ACTION"
      --profile "$profile"
      --matrix-file "$MATRIX_FILE"
    )

    if [[ "$VERBOSE" == 'true' ]]; then
      cmd+=( --verbose )
    fi

    if [[ "$DRY_RUN" == 'true' ]]; then
      cmd+=( --dry-run )
    fi

    if [[ "$APPLY_MODE" == 'true' ]]; then
      cmd+=( --apply )
    fi

    if ! vm_run_or_echo "$DRY_RUN" "${cmd[@]}"; then
      failures=$((failures + 1))
      vm_log_error "Action '${ACTION}' failed for profile '${profile}'"
    fi
  done <<< "$profiles"

  if [[ "$failures" -gt 0 ]]; then
    vm_die "Matrix action completed with ${failures} failure(s)."
  fi

  vm_log_info "Matrix action '${ACTION}' completed successfully."
}

main "$@"
