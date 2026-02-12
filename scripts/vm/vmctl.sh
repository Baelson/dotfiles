#!/usr/bin/env bash
# Local macOS VM infrastructure controller for dotfiles end-to-end testing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/vm/lib.sh
source "${SCRIPT_DIR}/lib.sh"

ACTION='doctor'
PROFILE=''
MATRIX_FILE="$(vm_default_matrix_file)"
STATE_DIR="${DOTFILES_VM_STATE_DIR:-${HOME}/.local/share/dotfiles-vm}"
SETUP_SCRIPT_URL="${DOTFILES_VM_SETUP_URL:-https://raw.githubusercontent.com/Baelson/dotfiles/main/setup.sh}"
SSH_KEY_PATH="${DOTFILES_VM_SSH_KEY:-}"
SSH_TIMEOUT_SECONDS=15
DRY_RUN='false'
VERBOSE='false'
APPLY_MODE='false'

BACKEND=''
TRACK=''
VM_NAME=''
IPSW_SOURCE=''
SSH_HOST_STRATEGY=''
SSH_HOST=''
SSH_PORT=''
SSH_USER=''

main() {
  parse_arguments "$@"
  validate_matrix

  case "$ACTION" in
    doctor)
      action_doctor
      ;;
    plan)
      ensure_profile_selected
      load_profile
      action_plan
      ;;
    create)
      ensure_profile_selected
      load_profile
      action_create
      ;;
    run-e2e)
      ensure_profile_selected
      load_profile
      action_run_e2e
      ;;
    *)
      vm_die "Unsupported action: ${ACTION}"
      ;;
  esac
}

show_help() {
  cat <<'EOF_HELP'
Local macOS VM controller

Usage:
  scripts/vm/vmctl.sh [options]

Options:
  -a, --action ACTION        Action: doctor | plan | create | run-e2e
  -p, --profile NAME         Matrix profile name (current | beta)
  -m, --matrix-file FILE     Matrix JSON file
  -s, --state-dir DIR        State directory for downloads and logs
  -r, --setup-url URL        setup.sh URL used by run-e2e
  -k, --ssh-key PATH         SSH private key path for guest login
  -t, --timeout SECONDS      SSH connect timeout in seconds
  -n, --dry-run              Print commands without executing them
  -A, --apply                For run-e2e: run full apply (not --dry-run)
  -v, --verbose              Print verbose diagnostic output
  -h, --help                 Show help output

Examples:
  scripts/vm/vmctl.sh --action doctor
  scripts/vm/vmctl.sh --action plan --profile current
  scripts/vm/vmctl.sh --action create --profile beta
  scripts/vm/vmctl.sh --action run-e2e --profile current --dry-run
  scripts/vm/vmctl.sh --action run-e2e --profile current --apply
EOF_HELP
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--action)
        ACTION="$2"
        shift 2
        ;;
      -p|--profile)
        PROFILE="$2"
        shift 2
        ;;
      -m|--matrix-file)
        MATRIX_FILE="$2"
        shift 2
        ;;
      -s|--state-dir)
        STATE_DIR="$2"
        shift 2
        ;;
      -r|--setup-url)
        SETUP_SCRIPT_URL="$2"
        shift 2
        ;;
      -k|--ssh-key)
        SSH_KEY_PATH="$2"
        shift 2
        ;;
      -t|--timeout)
        SSH_TIMEOUT_SECONDS="$2"
        shift 2
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

  if [[ -z "$PROFILE" && "$ACTION" != 'doctor' ]]; then
    PROFILE='current'
  fi
}

validate_matrix() {
  [[ -f "$MATRIX_FILE" ]] || vm_die "Matrix file not found: ${MATRIX_FILE}"

  if ! vm_matrix_validate_schema "$MATRIX_FILE" >/dev/null; then
    vm_die "Matrix validation failed: ${MATRIX_FILE}"
  fi
}

ensure_profile_selected() {
  [[ -n "$PROFILE" ]] || vm_die 'Profile is required for this action.'

  if ! vm_matrix_profile_exists "$MATRIX_FILE" "$PROFILE"; then
    vm_die "Profile not found in matrix: ${PROFILE}"
  fi
}

load_profile() {
  BACKEND="$(vm_matrix_profile_field "$MATRIX_FILE" "$PROFILE" 'backend')"
  TRACK="$(vm_matrix_profile_field "$MATRIX_FILE" "$PROFILE" 'track')"
  VM_NAME="$(vm_matrix_profile_field "$MATRIX_FILE" "$PROFILE" 'vm_name')"
  IPSW_SOURCE="$(vm_matrix_profile_field "$MATRIX_FILE" "$PROFILE" 'ipsw')"
  SSH_HOST_STRATEGY="$(vm_matrix_profile_field "$MATRIX_FILE" "$PROFILE" 'ssh_host_strategy')"
  SSH_HOST="$(vm_matrix_profile_field "$MATRIX_FILE" "$PROFILE" 'ssh_host')"
  SSH_PORT="$(vm_matrix_profile_field "$MATRIX_FILE" "$PROFILE" 'ssh_port')"
  SSH_USER="$(vm_matrix_profile_field "$MATRIX_FILE" "$PROFILE" 'ssh_user')"

  [[ -n "$BACKEND" ]] || vm_die "Profile '${PROFILE}' is missing backend"
  [[ -n "$VM_NAME" ]] || vm_die "Profile '${PROFILE}' is missing vm_name"
  [[ -n "$IPSW_SOURCE" ]] || vm_die "Profile '${PROFILE}' is missing ipsw"
  [[ -n "$SSH_HOST_STRATEGY" ]] || vm_die "Profile '${PROFILE}' is missing ssh_host_strategy"
  [[ -n "$SSH_PORT" ]] || vm_die "Profile '${PROFILE}' is missing ssh_port"
  [[ -n "$SSH_USER" ]] || vm_die "Profile '${PROFILE}' is missing ssh_user"
}

action_doctor() {
  local failures=0
  local warnings=0
  local profile_name=''
  local profile_names=''

  vm_log_info "Matrix file: ${MATRIX_FILE}"

  if [[ "$(uname -s)" != 'Darwin' ]]; then
    vm_log_error 'macOS host is required for native macOS virtualization.'
    failures=$((failures + 1))
  fi

  if [[ "$(uname -m)" != 'arm64' ]]; then
    vm_log_error 'Apple Silicon (arm64) is required for macOS guest virtualization.'
    failures=$((failures + 1))
  fi

  vm_require_command 'python3' 'Install Python 3 before using VM matrix tools.' || failures=$((failures + 1))
  vm_require_command 'ssh' 'Install OpenSSH client tools.' || failures=$((failures + 1))

  profile_names="$(vm_matrix_profiles "$MATRIX_FILE" 'false')"
  while IFS= read -r profile_name; do
    [[ -n "$profile_name" ]] || continue

    PROFILE="$profile_name"
    load_profile

    if [[ "$VERBOSE" == 'true' ]]; then
      vm_log_info "Checking profile '${PROFILE}' (backend=${BACKEND}, track=${TRACK})"
    fi

    case "$BACKEND" in
      tart)
        if ! command -v tart >/dev/null 2>&1; then
          vm_log_error "Profile '${PROFILE}': backend 'tart' is not installed or not on PATH"
          vm_log_error "Install tart manually from https://tart.run/ then re-run doctor."
          failures=$((failures + 1))
        fi
        ;;
      *)
        vm_log_error "Profile '${PROFILE}': unsupported backend '${BACKEND}'"
        failures=$((failures + 1))
        ;;
    esac

    if [[ "$IPSW_SOURCE" == 'REPLACE_WITH_LOCAL_BETA_IPSW_PATH' ]]; then
      vm_log_warn "Profile '${PROFILE}': beta IPSW path placeholder still set"
      warnings=$((warnings + 1))
    elif [[ "$IPSW_SOURCE" != 'latest' && "$IPSW_SOURCE" != http://* && "$IPSW_SOURCE" != https://* && ! -f "$IPSW_SOURCE" ]]; then
      vm_log_warn "Profile '${PROFILE}': IPSW path does not exist yet: ${IPSW_SOURCE}"
      warnings=$((warnings + 1))
    fi

    if [[ "$SSH_HOST_STRATEGY" == 'fixed' && -z "$SSH_HOST" ]]; then
      vm_log_error "Profile '${PROFILE}': ssh_host_strategy=fixed requires ssh_host"
      failures=$((failures + 1))
    fi
  done <<< "$profile_names"

  if [[ "$failures" -gt 0 ]]; then
    vm_log_error "Doctor failed: ${failures} blocking issue(s), ${warnings} warning(s)."
    return 1
  fi

  vm_log_info "Doctor passed with ${warnings} warning(s)."
  return 0
}

action_plan() {
  vm_log_info "Profile: ${PROFILE}"
  vm_log_info "Backend: ${BACKEND}"
  vm_log_info "Track: ${TRACK}"
  vm_log_info "VM Name: ${VM_NAME}"
  vm_log_info "IPSW Source: ${IPSW_SOURCE}"

  cat <<EOF_PLAN

Plan for profile '${PROFILE}':
1) Create VM image
   tart create --from-ipsw=${IPSW_SOURCE} ${VM_NAME}

2) Start the VM (manual first-boot recommended)
   tart run ${VM_NAME}

3) Resolve guest IP and test connectivity
   tart ip ${VM_NAME}
   ssh -p ${SSH_PORT} ${SSH_USER}@<guest-ip>

4) Run setup in dry-run mode inside guest
   curl --fail --silent --show-error --location ${SETUP_SCRIPT_URL} | zsh -s -- --dry-run --debug-verbose

5) Run setup apply inside guest (full end-to-end)
   curl --fail --silent --show-error --location ${SETUP_SCRIPT_URL} | zsh

6) Verify expected state inside guest
   chezmoi doctor
   test -f ~/.zshrc
   test -f ~/Brewfile
EOF_PLAN
}

action_create() {
  [[ "$BACKEND" == 'tart' ]] || vm_die "Create currently supports only backend=tart"
  vm_require_command 'tart' 'Install tart before creating VMs.' || return 1

  if [[ "$IPSW_SOURCE" == 'REPLACE_WITH_LOCAL_BETA_IPSW_PATH' ]]; then
    vm_die "Profile '${PROFILE}' still uses placeholder IPSW path. Update matrix first."
  fi

  local resolved_ipsw="$IPSW_SOURCE"
  local vm_exists='false'

  if tart list 2>/dev/null | grep -Eq "(^|[[:space:]])${VM_NAME}([[:space:]]|$)"; then
    vm_exists='true'
  fi

  if [[ "$vm_exists" == 'true' ]]; then
    vm_log_info "VM already exists: ${VM_NAME}"
    return 0
  fi

  mkdir -p "$STATE_DIR/ipsw"

  if [[ "$IPSW_SOURCE" == http://* || "$IPSW_SOURCE" == https://* ]]; then
    local download_path="${STATE_DIR}/ipsw/${PROFILE}.ipsw"

    # single-line CLI: curl --fail --silent --show-error --location --output "${download_path}" "${IPSW_SOURCE}"
    local -a curl_args=(
      --fail        # Fail on HTTP response errors.
      --silent      # Hide progress meter for cleaner logs.
      --show-error  # Show transfer errors even with --silent.
      --location    # Follow redirects for hosted artifacts.
      --output "$download_path"
      "$IPSW_SOURCE"
    )

    vm_log_info "Downloading IPSW for profile '${PROFILE}'"
    vm_run_or_echo "$DRY_RUN" curl "${curl_args[@]}"
    resolved_ipsw="$download_path"
  elif [[ "$IPSW_SOURCE" != 'latest' && ! -f "$IPSW_SOURCE" ]]; then
    vm_die "IPSW path does not exist: ${IPSW_SOURCE}"
  fi

  vm_log_info "Creating VM '${VM_NAME}' from IPSW source '${resolved_ipsw}'"
  vm_run_or_echo "$DRY_RUN" tart create "--from-ipsw=${resolved_ipsw}" "$VM_NAME"
}

resolve_guest_host() {
  if [[ "$SSH_HOST_STRATEGY" == 'fixed' ]]; then
    [[ -n "$SSH_HOST" ]] || vm_die "Profile '${PROFILE}' requires ssh_host when ssh_host_strategy=fixed"
    printf '%s\n' "$SSH_HOST"
    return 0
  fi

  if [[ "$SSH_HOST_STRATEGY" == 'tart-ip' ]]; then
    vm_require_command 'tart' 'Install tart before resolving guest IP.' || return 1
    local ip
    ip="$(tart ip "$VM_NAME" 2>/dev/null || true)"
    [[ -n "$ip" ]] || vm_die "Unable to resolve VM IP via 'tart ip ${VM_NAME}'. Start the VM first."
    printf '%s\n' "$ip"
    return 0
  fi

  vm_die "Unsupported ssh_host_strategy: ${SSH_HOST_STRATEGY}"
}

action_run_e2e() {
  local guest_host=''
  local setup_args='--dry-run --debug-verbose'

  vm_require_command 'ssh' 'Install OpenSSH client tools.' || return 1

  guest_host="$(resolve_guest_host)"

  if [[ "$APPLY_MODE" == 'true' ]]; then
    setup_args=''
  fi

  local -a ssh_args=(
    -o "BatchMode=yes"
    -o "StrictHostKeyChecking=accept-new"
    -o "ConnectTimeout=${SSH_TIMEOUT_SECONDS}"
    -p "$SSH_PORT"
  )

  if [[ -n "$SSH_KEY_PATH" ]]; then
    ssh_args+=( -i "$SSH_KEY_PATH" )
  fi

  local target="${SSH_USER}@${guest_host}"

  vm_log_info "Running E2E for profile '${PROFILE}' against ${target}:${SSH_PORT}"

  # single-line CLI: ssh <opts> "${target}" "echo vm-ready"
  vm_run_or_echo "$DRY_RUN" ssh "${ssh_args[@]}" "$target" 'echo vm-ready'

  # single-line CLI: ssh <opts> "${target}" "curl --fail --silent --show-error --location ${SETUP_SCRIPT_URL} | zsh -s -- ${setup_args}"
  vm_run_or_echo "$DRY_RUN" ssh "${ssh_args[@]}" "$target" \
    "curl --fail --silent --show-error --location ${SETUP_SCRIPT_URL} | zsh -s -- ${setup_args}"

  if [[ "$APPLY_MODE" == 'true' ]]; then
    # single-line CLI: ssh <opts> "${target}" "chezmoi doctor && test -f ~/.zshrc && test -f ~/Brewfile"
    vm_run_or_echo "$DRY_RUN" ssh "${ssh_args[@]}" "$target" \
      'chezmoi doctor && test -f ~/.zshrc && test -f ~/Brewfile'
  else
    vm_log_info 'Skipped filesystem assertions because run-e2e is in dry-run mode.'
    vm_log_info 'Re-run with --apply to verify persisted files inside the guest VM.'
  fi
}

main "$@"
