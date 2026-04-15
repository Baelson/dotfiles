#!/usr/bin/env bash
# Initialize a writable local VM matrix from the tracked template.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/vm/lib.sh
source "${SCRIPT_DIR}/lib.sh"

MATRIX_TEMPLATE="$(vm_repo_root)/infrastructure/vm/macos-matrix.example.json"
MATRIX_OUTPUT="$(vm_repo_root)/infrastructure/vm/macos-matrix.local.json"
FORCE_WRITE='false'

main() {
  parse_arguments "$@"
  initialize_matrix
}

show_help() {
  cat <<'EOF_HELP'
Initialize local VM matrix configuration

Usage:
  scripts/vm/init-matrix.sh [options]

Options:
  -m, --matrix-template FILE   Source matrix template file
  -o, --output-file FILE       Destination matrix file
  -f, --force                  Overwrite destination if it exists
  -h, --help                   Show help output
EOF_HELP
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--matrix-template)
        MATRIX_TEMPLATE="$2"
        shift 2
        ;;
      -o|--output-file)
        MATRIX_OUTPUT="$2"
        shift 2
        ;;
      -f|--force)
        FORCE_WRITE='true'
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

initialize_matrix() {
  [[ -f "${MATRIX_TEMPLATE}" ]] || vm_die "Matrix template not found: ${MATRIX_TEMPLATE}"

  if [[ -f "${MATRIX_OUTPUT}" && "${FORCE_WRITE}" != 'true' ]]; then
    vm_die "Output already exists: ${MATRIX_OUTPUT}. Re-run with --force to overwrite."
  fi

  mkdir -p "$(dirname "${MATRIX_OUTPUT}")"
  cp "${MATRIX_TEMPLATE}" "${MATRIX_OUTPUT}"

  vm_log_info "Created local VM matrix: ${MATRIX_OUTPUT}"
  vm_log_info "Next: update beta profile ipsw path in ${MATRIX_OUTPUT}"
}

main "$@"
