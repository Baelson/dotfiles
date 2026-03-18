# shellcheck shell=bash
# Shared helpers for local macOS VM infrastructure scripts.

set -euo pipefail

vm_log_info() {
  printf '[INFO] %s\n' "$1"
}

vm_log_warn() {
  printf '[WARN] %s\n' "$1" >&2
}

vm_log_error() {
  printf '[ERROR] %s\n' "$1" >&2
}

vm_die() {
  vm_log_error "$1"
  exit 1
}

vm_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  dirname "$(dirname "$script_dir")"
}

vm_default_matrix_file() {
  local repo_root
  local local_matrix
  local example_matrix

  repo_root="$(vm_repo_root)"
  local_matrix="${repo_root}/infrastructure/vm/macos-matrix.local.json"
  example_matrix="${repo_root}/infrastructure/vm/macos-matrix.example.json"

  if [[ -f "$local_matrix" ]]; then
    printf '%s\n' "$local_matrix"
    return 0
  fi

  printf '%s\n' "$example_matrix"
}

vm_require_command() {
  local command_name="$1"
  local install_hint="$2"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    vm_log_error "Missing required command: ${command_name}"
    if [[ -n "$install_hint" ]]; then
      vm_log_error "Install hint: ${install_hint}"
    fi
    return 1
  fi

  return 0
}

vm_print_command() {
  local escaped=''
  local arg

  for arg in "$@"; do
    escaped+="$(printf '%q' "$arg") "
  done

  printf '%s\n' "${escaped% }"
}

vm_run_or_echo() {
  local dry_run="$1"
  shift

  if [[ "$dry_run" == 'true' ]]; then
    vm_log_info "[dry-run] $(vm_print_command "$@")"
    return 0
  fi

  "$@"
}

vm_matrix_validate_schema() {
  local matrix_file="$1"

  python3 - "$matrix_file" <<'PY'
import json
import pathlib
import sys

matrix_path = pathlib.Path(sys.argv[1])
if not matrix_path.exists():
    print(f"matrix file not found: {matrix_path}", file=sys.stderr)
    sys.exit(2)

with matrix_path.open("r", encoding="utf-8") as handle:
    try:
        data = json.load(handle)
    except json.JSONDecodeError as exc:
        print(f"invalid JSON in {matrix_path}: {exc}", file=sys.stderr)
        sys.exit(3)

if not isinstance(data, dict):
    print("matrix root must be an object", file=sys.stderr)
    sys.exit(4)

profiles = data.get("profiles")
if not isinstance(profiles, list) or len(profiles) == 0:
    print("matrix must include at least one profile", file=sys.stderr)
    sys.exit(5)

required_keys = {
    "name",
    "enabled",
    "backend",
    "track",
    "vm_name",
    "ipsw",
    "ssh_host_strategy",
    "ssh_port",
    "ssh_user",
}

for index, profile in enumerate(profiles):
    if not isinstance(profile, dict):
        print(f"profile[{index}] must be an object", file=sys.stderr)
        sys.exit(6)

    missing = [key for key in sorted(required_keys) if key not in profile]
    if missing:
        joined = ", ".join(missing)
        print(f"profile[{index}] missing required keys: {joined}", file=sys.stderr)
        sys.exit(7)

print("ok")
PY
}

vm_matrix_profiles() {
  local matrix_file="$1"
  local only_enabled="$2"

  python3 - "$matrix_file" "$only_enabled" <<'PY'
import json
import sys

matrix_file = sys.argv[1]
only_enabled = sys.argv[2] == "true"

with open(matrix_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

for profile in data.get("profiles", []):
    if only_enabled and not bool(profile.get("enabled", False)):
        continue
    name = str(profile.get("name", "")).strip()
    if name:
        print(name)
PY
}

vm_matrix_profile_exists() {
  local matrix_file="$1"
  local profile_name="$2"

  python3 - "$matrix_file" "$profile_name" <<'PY'
import json
import sys

matrix_file, profile_name = sys.argv[1], sys.argv[2]

with open(matrix_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

for profile in data.get("profiles", []):
    if str(profile.get("name", "")).strip() == profile_name:
        sys.exit(0)

sys.exit(1)
PY
}

vm_matrix_profile_field() {
  local matrix_file="$1"
  local profile_name="$2"
  local field_name="$3"

  python3 - "$matrix_file" "$profile_name" "$field_name" <<'PY'
import json
import sys

matrix_file, profile_name, field_name = sys.argv[1], sys.argv[2], sys.argv[3]

with open(matrix_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

for profile in data.get("profiles", []):
    if str(profile.get("name", "")).strip() != profile_name:
        continue

    value = profile
    for part in field_name.split('.'):
        if isinstance(value, dict) and part in value:
            value = value[part]
        else:
            print("")
            sys.exit(0)

    if isinstance(value, bool):
        print("true" if value else "false")
    elif value is None:
        print("")
    else:
        print(value)
    sys.exit(0)

print("")
sys.exit(1)
PY
}

vm_is_running() {
  local vm_name="$1"
  # tart list columns: Source Name ... State (last column)
  # Name is column 2, State is $NF
  if tart list 2>/dev/null | awk -v name="$vm_name" '$2 == name && $NF == "running" { found=1 } END { exit !found }'; then
    return 0
  fi
  return 1
}

vm_wait_for_ssh() {
  local vm_name="$1"
  local ssh_user="$2"
  local ssh_port="$3"
  local max_wait="${4:-120}"
  local ssh_key_path="${5:-}"

  local elapsed=0
  local interval=5
  local guest_ip=""
  local last_ssh_error=""

  vm_log_info "Waiting up to ${max_wait}s for SSH on VM '${vm_name}'..."

  while [[ "$elapsed" -lt "$max_wait" ]]; do
    guest_ip="$(tart ip "$vm_name" 2>/dev/null || true)"

    if [[ -n "$guest_ip" ]]; then
      local -a ssh_args=(
        -o "BatchMode=yes"
        -o "StrictHostKeyChecking=accept-new"
        -o "ConnectTimeout=5"
        -p "$ssh_port"
      )
      if [[ -n "$ssh_key_path" ]]; then
        ssh_args+=( -i "$ssh_key_path" )
      fi

      # Capture stderr so we can report the last failure reason on timeout
      last_ssh_error="$(ssh "${ssh_args[@]}" "${ssh_user}@${guest_ip}" 'echo vm-ready' 2>&1 >/dev/null || true)"

      if [[ -z "$last_ssh_error" ]]; then
        vm_log_info "SSH ready at ${guest_ip} after ${elapsed}s"
        printf '%s\n' "$guest_ip"
        return 0
      fi
    else
      last_ssh_error="tart ip returned no address"
    fi

    sleep "$interval"
    elapsed=$((elapsed + interval))
    # Exponential backoff capped at 30s
    if [[ "$interval" -lt 30 ]]; then
      interval=$((interval + 5))
    fi
  done

  vm_log_error "SSH not ready after ${max_wait}s for VM '${vm_name}'"
  if [[ -n "$guest_ip" ]]; then
    vm_log_error "Last resolved IP: ${guest_ip}"
  fi
  if [[ -n "$last_ssh_error" ]]; then
    vm_log_error "Last SSH error: ${last_ssh_error}"
  fi

  # Provide actionable guidance based on the failure pattern
  if [[ "$last_ssh_error" == *'Connection refused'* ]]; then
    vm_log_error "Remote Login (SSH) is not enabled in the guest."
    vm_log_error "Enable it: System Settings → General → Sharing → Remote Login"
    vm_log_error "Then configure authorized_keys for user '${ssh_user}'."
  elif [[ "$last_ssh_error" == *'Permission denied'* ]]; then
    vm_log_error "SSH authentication failed. Check ssh_key and authorized_keys for user '${ssh_user}'."
  elif [[ "$last_ssh_error" == *'No route to host'* ]] || [[ "$last_ssh_error" == *'Operation timed out'* ]]; then
    vm_log_error "Guest network is not reachable. Verify VM networking configuration."
  fi

  return 1
}

vm_verify_manifest() {
  local manifest_file="$1"
  local target="$2"
  local log_file="$3"
  shift 3
  local -a ssh_args=( "$@" )

  local total=0
  local passed=0
  local failed=0
  local line_type=""
  local line_path=""
  local line_pattern=""
  local check_cmd=""
  local result=""

  {
    printf '=== Verification manifest: %s ===\n' "$manifest_file"
    printf '=== Target: %s ===\n' "$target"
    printf '=== Started: %s ===\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip comments and blank lines
      if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// /}" ]]; then
        continue
      fi

      # Parse fields: type path [pattern]
      line_type="$(printf '%s' "$line" | awk '{print $1}')"
      line_path="$(printf '%s' "$line" | awk '{print $2}')"
      line_pattern="$(printf '%s' "$line" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')"

      total=$((total + 1))
      check_cmd=""

      case "$line_type" in
        file)
          check_cmd="test -f \"\$HOME/${line_path}\""
          ;;
        dir)
          check_cmd="test -d \"\$HOME/${line_path}\""
          ;;
        symlink)
          check_cmd="test -L \"\$HOME/${line_path}\""
          ;;
        contains)
          check_cmd="grep -q '${line_pattern}' \"\$HOME/${line_path}\""
          ;;
        cmd)
          # Everything after 'cmd ' is the command
          check_cmd="$(printf '%s' "$line" | sed 's/^cmd[[:space:]]*//')"
          ;;
        *)
          printf '[SKIP] Unknown type: %s\n' "$line_type"
          total=$((total - 1))
          continue
          ;;
      esac

      set +e
      ssh "${ssh_args[@]}" "$target" "$check_cmd" >/dev/null 2>&1
      result=$?
      set -e

      if [[ "$result" -eq 0 ]]; then
        printf '[PASS] %s %s %s\n' "$line_type" "$line_path" "$line_pattern"
        passed=$((passed + 1))
      else
        printf '[FAIL] %s %s %s\n' "$line_type" "$line_path" "$line_pattern"
        failed=$((failed + 1))
      fi
    done < "$manifest_file"

    printf '\n=== Summary: %d passed, %d failed, %d total ===\n' "$passed" "$failed" "$total"
  } | tee "$log_file"

  # The pipeline runs the block in a subshell, so $failed is not visible here.
  # Check the log file for [FAIL] markers instead.
  if grep -q '\[FAIL\]' "$log_file"; then
    return 1
  fi
  return 0
}

vm_capture_log() {
  local target="$1"
  local remote_command="$2"
  local log_file="$3"
  shift 3
  local -a ssh_args=( "$@" )
  local ssh_status=0

  {
    printf '=== Log capture: %s ===\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '=== Command: %s ===\n\n' "$remote_command"
  } > "$log_file"

  set +e
  ssh "${ssh_args[@]}" "$target" "$remote_command" 2>&1 | tee -a "$log_file"
  ssh_status=${PIPESTATUS[0]}
  set -e

  return "$ssh_status"
}
