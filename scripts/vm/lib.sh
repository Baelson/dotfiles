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
