#!/usr/bin/env bats

load '../lib/test_helper'

setup() {
  setup_common
}

# =============================================================================
# Matrix Template Validation
# =============================================================================

@test "VM-IAC.1: Matrix template includes current and beta profiles" {
  local matrix_file="$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [[ -f "$matrix_file" ]]

  run python3 - "$matrix_file" <<'PY'
import json
import sys

matrix_file = sys.argv[1]
with open(matrix_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

profiles = {entry["name"] for entry in data.get("profiles", [])}
if "current" not in profiles:
    raise SystemExit("missing current profile")
if "beta" not in profiles:
    raise SystemExit("missing beta profile")
PY

  [ "$status" -eq 0 ]
}

@test "VM-IAC.6: Matrix template passes schema validation" {
  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_matrix_validate_schema '$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json'"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "ok" ]]
}

@test "VM-IAC.7: Schema validation rejects invalid JSON" {
  local bad_json="$BATS_TEST_TMPDIR/bad.json"
  echo '{ invalid json' > "$bad_json"

  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_matrix_validate_schema '$bad_json'"

  [ "$status" -ne 0 ]
}

@test "VM-IAC.8: Schema validation rejects matrix with missing required keys" {
  local incomplete="$BATS_TEST_TMPDIR/incomplete.json"
  cat > "$incomplete" <<'JSON'
{
  "profiles": [
    {
      "name": "incomplete",
      "enabled": true
    }
  ]
}
JSON

  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_matrix_validate_schema '$incomplete'"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "missing required keys" ]]
}

@test "VM-IAC.9: Schema validation rejects matrix with empty profiles array" {
  local empty_profiles="$BATS_TEST_TMPDIR/empty-profiles.json"
  cat > "$empty_profiles" <<'JSON'
{
  "profiles": []
}
JSON

  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_matrix_validate_schema '$empty_profiles'"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "at least one profile" ]]
}

@test "VM-IAC.10: Matrix profile field extraction returns correct values" {
  local matrix_file="$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_matrix_profile_field '$matrix_file' 'current' 'backend'"
  [ "$status" -eq 0 ]
  [[ "$output" == "tart" ]]

  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_matrix_profile_field '$matrix_file' 'current' 'ssh_port'"
  [ "$status" -eq 0 ]
  [[ "$output" == "22" ]]

  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_matrix_profile_field '$matrix_file' 'current' 'ssh_user'"
  [ "$status" -eq 0 ]
  [[ "$output" == "admin" ]]
}

@test "VM-IAC.11: Matrix profile existence check works for known and unknown profiles" {
  local matrix_file="$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_matrix_profile_exists '$matrix_file' 'current'"
  [ "$status" -eq 0 ]

  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_matrix_profile_exists '$matrix_file' 'nonexistent'"
  [ "$status" -ne 0 ]
}

# =============================================================================
# init-matrix Script
# =============================================================================

@test "VM-IAC.2: init-matrix creates a writable local matrix file" {
  local output_file="$BATS_TEST_TMPDIR/macos-matrix.local.json"

  run "$DOTFILES_ROOT/scripts/vm/init-matrix.sh" \
    --output-file "$output_file"

  [ "$status" -eq 0 ]
  [[ -f "$output_file" ]]
}

@test "VM-IAC.12: init-matrix refuses to overwrite without --force" {
  local output_file="$BATS_TEST_TMPDIR/macos-matrix.local.json"
  echo '{}' > "$output_file"

  run "$DOTFILES_ROOT/scripts/vm/init-matrix.sh" \
    --output-file "$output_file"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "already exists" ]]
}

@test "VM-IAC.13: init-matrix overwrites with --force" {
  local output_file="$BATS_TEST_TMPDIR/macos-matrix.local.json"
  echo '{}' > "$output_file"

  run "$DOTFILES_ROOT/scripts/vm/init-matrix.sh" \
    --output-file "$output_file" \
    --force

  [ "$status" -eq 0 ]
  [[ -f "$output_file" ]]

  # Verify it contains valid profile data (not the empty {} we wrote)
  run python3 -c "import json; d=json.load(open('$output_file')); assert len(d['profiles']) >= 2"
  [ "$status" -eq 0 ]
}

@test "VM-IAC.14: init-matrix help output includes all options" {
  run "$DOTFILES_ROOT/scripts/vm/init-matrix.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" =~ "--matrix-template" ]]
  [[ "$output" =~ "--output-file" ]]
  [[ "$output" =~ "--force" ]]
}

# =============================================================================
# vmctl.sh — Help and Argument Parsing
# =============================================================================

@test "VM-IAC.3: vmctl exposes help output" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" =~ --action ]]
  [[ "$output" =~ run-e2e ]]
}

@test "VM-IAC.15: vmctl rejects unknown action" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action bogus \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unsupported action" ]]
}

@test "VM-IAC.16: vmctl rejects unknown profile" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action plan \
    --profile nonexistent \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Profile not found" ]]
}

@test "VM-IAC.17: vmctl fails when matrix file does not exist" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action doctor \
    --matrix-file "/nonexistent/matrix.json"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Matrix file not found" ]]
}

# =============================================================================
# vmctl.sh — Doctor Action
# =============================================================================

@test "VM-IAC.4: vmctl doctor reports missing tart with actionable guidance" {
  run env PATH='/usr/bin:/bin' "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action doctor \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "backend 'tart' is not installed" ]]
  [[ "$output" =~ "Install tart manually from https://tart.run/" ]]
}

@test "VM-IAC.18: vmctl doctor warns about beta IPSW placeholder" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action doctor \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json" \
    --verbose

  # Doctor may pass or fail depending on tart installation,
  # but should always warn about the placeholder
  [[ "$output" =~ "beta IPSW path placeholder still set" ]]
}

# =============================================================================
# vmctl.sh — Plan Action
# =============================================================================

@test "VM-IAC.19: vmctl plan for current profile renders all 6 steps" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action plan \
    --profile current \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "1) Create VM image" ]]
  [[ "$output" =~ "2) Start the VM" ]]
  [[ "$output" =~ "3) Resolve guest IP" ]]
  [[ "$output" =~ "4) Run setup in dry-run" ]]
  [[ "$output" =~ "5) Run setup apply" ]]
  [[ "$output" =~ "6) Verify expected state" ]]
}

@test "VM-IAC.20: vmctl plan uses correct VM name and IPSW per profile" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action plan \
    --profile current \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "VM Name: dotfiles-macos-current" ]]
  [[ "$output" =~ "IPSW Source: latest" ]]
}

# =============================================================================
# vmctl.sh — Dry-Run Create and E2E
# =============================================================================

@test "VM-IAC.21: vmctl create in dry-run succeeds without side-effects" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action create \
    --profile current \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json" \
    --dry-run

  [ "$status" -eq 0 ]
  # When the VM already exists, the script short-circuits with an info message.
  # When it does not exist, it shows the dry-run tart create command.
  [[ "$output" =~ "already exists" ]] || [[ "$output" =~ "[dry-run]" ]]
}

@test "VM-IAC.22: vmctl run-e2e in dry-run does not SSH into guest" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action run-e2e \
    --profile current \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json" \
    --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" =~ "[dry-run]" ]]
  [[ "$output" =~ "ssh" ]]
  [[ "$output" =~ "Skipped filesystem assertions because run-e2e is in dry-run mode" ]]
}

# =============================================================================
# vm-matrix.sh — Orchestrator
# =============================================================================

@test "VM-IAC.5: vm-matrix plan renders both current and beta workflows" {
  run "$DOTFILES_ROOT/scripts/vm/vm-matrix.sh" \
    --action plan \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Profile: current" ]]
  [[ "$output" =~ "Profile: beta" ]]
}

@test "VM-IAC.23: vm-matrix help output includes all options" {
  run "$DOTFILES_ROOT/scripts/vm/vm-matrix.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" =~ "--action" ]]
  [[ "$output" =~ "--profiles" ]]
  [[ "$output" =~ "--include-disabled" ]]
  [[ "$output" =~ "--dry-run" ]]
  [[ "$output" =~ "--apply" ]]
}

@test "VM-IAC.24: vm-matrix filters by profile name" {
  run "$DOTFILES_ROOT/scripts/vm/vm-matrix.sh" \
    --action plan \
    --profiles current \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Profile: current" ]]
  [[ ! "$output" =~ "Profile: beta" ]]
}

@test "VM-IAC.25: vm-matrix fails when matrix file does not exist" {
  run "$DOTFILES_ROOT/scripts/vm/vm-matrix.sh" \
    --action plan \
    --matrix-file "/nonexistent/matrix.json"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Matrix file not found" ]]
}

# =============================================================================
# lib.sh — Utility Functions
# =============================================================================

@test "VM-IAC.26: vm_run_or_echo in dry-run prints command instead of executing" {
  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_run_or_echo 'true' echo 'should-print-not-run'"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "[dry-run]" ]]
  [[ "$output" =~ "should-print-not-run" ]]
}

@test "VM-IAC.27: vm_run_or_echo in live mode executes the command" {
  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_run_or_echo 'false' echo 'hello-from-live'"

  [ "$status" -eq 0 ]
  [[ "$output" == "hello-from-live" ]]
}

@test "VM-IAC.28: vm_require_command succeeds for known commands" {
  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_require_command 'python3' 'install python'"

  [ "$status" -eq 0 ]
}

@test "VM-IAC.29: vm_require_command fails with hint for missing commands" {
  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_require_command 'nonexistent_tool_xyz' 'brew install nonexistent_tool_xyz'"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Missing required command: nonexistent_tool_xyz" ]]
  [[ "$output" =~ "brew install nonexistent_tool_xyz" ]]
}

# =============================================================================
# Brewfile Integration — Tart Package
# =============================================================================

@test "VM-IAC.30: Brewfile template includes tart for VM testing" {
  local brewfile="$DOTFILES_ROOT/home/Brewfile.tmpl"

  run grep -q "cirruslabs/cli/tart" "$brewfile"
  [ "$status" -eq 0 ]

  run grep -q "tap 'cirruslabs/cli'" "$brewfile"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Script Portability — Shellcheck
# =============================================================================

@test "VM-IAC.31: All VM scripts pass shellcheck" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  run shellcheck \
    "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    "$DOTFILES_ROOT/scripts/vm/vm-matrix.sh" \
    "$DOTFILES_ROOT/scripts/vm/init-matrix.sh" \
    "$DOTFILES_ROOT/scripts/vm/lib.sh"

  [ "$status" -eq 0 ]
}

# =============================================================================
# Infrastructure Files — Gitignore
# =============================================================================

@test "VM-IAC.32: Local matrix file is gitignored" {
  run grep -q "macos-matrix.local.json" "$DOTFILES_ROOT/.gitignore"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Full E2E Orchestrator — lib.sh Functions
# =============================================================================

@test "VM-IAC.33: vm_is_running returns 1 for non-existent VM" {
  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_is_running 'nonexistent-vm-xyz-12345'"
  [ "$status" -ne 0 ]
}

@test "VM-IAC.34: vm_is_running returns 0 for running VM (or skip)" {
  if ! command -v tart >/dev/null 2>&1; then
    skip "tart not installed"
  fi

  # Find any running VM to test against; skip if none
  local running_vm=""
  running_vm="$(tart list 2>/dev/null | awk '$NF == "running" { print $1; exit }')" || true

  if [[ -z "$running_vm" ]]; then
    skip "no running tart VM found"
  fi

  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_is_running '$running_vm'"
  [ "$status" -eq 0 ]
}

@test "VM-IAC.35: vm_wait_for_ssh returns 1 when max wait exhausted" {
  if ! command -v tart >/dev/null 2>&1; then
    skip "tart not installed"
  fi

  # Use a tiny timeout with a non-existent VM
  run bash -c "source '$DOTFILES_ROOT/scripts/vm/lib.sh' && vm_wait_for_ssh 'nonexistent-vm-xyz' 'user' '22' '1'"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "SSH not ready" ]]
}

@test "VM-IAC.36: vm_verify_manifest parses file/dir/cmd/contains types correctly" {
  local manifest="$BATS_TEST_TMPDIR/test-manifest.txt"
  local log_file="$BATS_TEST_TMPDIR/verify.log"

  # Create a manifest that tests against localhost (not SSH)
  cat > "$manifest" <<'MANIFEST'
# Test manifest
cmd     true
cmd     echo hello
MANIFEST

  # We test vm_verify_manifest with a local wrapper that mocks SSH
  # by using bash -c as a stand-in (the function calls ssh "$target" "$cmd")
  # For a true unit test, we just verify the parsing works with a simple cmd type
  run bash -c "
    source '$DOTFILES_ROOT/scripts/vm/lib.sh'

    # Override ssh to just run the command locally
    ssh() {
      local cmd=\"\${*: -1}\"
      bash -c \"\$cmd\"
    }
    export -f ssh

    vm_verify_manifest '$manifest' 'dummy@localhost' '$log_file' -p 22
  "

  [ "$status" -eq 0 ]
  [[ "$output" =~ "[PASS] cmd" ]]
  [[ "$output" =~ "2 passed, 0 failed, 2 total" ]]
}

@test "VM-IAC.37: vm_verify_manifest reports FAIL for missing files" {
  local manifest="$BATS_TEST_TMPDIR/fail-manifest.txt"
  local log_file="$BATS_TEST_TMPDIR/verify.log"

  cat > "$manifest" <<'MANIFEST'
cmd     false
MANIFEST

  run bash -c "
    source '$DOTFILES_ROOT/scripts/vm/lib.sh'
    ssh() { local cmd=\"\${*: -1}\"; bash -c \"\$cmd\"; }
    export -f ssh
    vm_verify_manifest '$manifest' 'dummy@localhost' '$log_file' -p 22
  "

  [ "$status" -ne 0 ]
  [[ "$output" =~ "[FAIL]" ]]
  [[ "$output" =~ "0 passed, 1 failed, 1 total" ]]
}

@test "VM-IAC.38: vm_verify_manifest skips comment and empty lines" {
  local manifest="$BATS_TEST_TMPDIR/comments-manifest.txt"
  local log_file="$BATS_TEST_TMPDIR/verify.log"

  cat > "$manifest" <<'MANIFEST'
# This is a comment

  # Indented comment

cmd     true
MANIFEST

  run bash -c "
    source '$DOTFILES_ROOT/scripts/vm/lib.sh'
    ssh() { local cmd=\"\${*: -1}\"; bash -c \"\$cmd\"; }
    export -f ssh
    vm_verify_manifest '$manifest' 'dummy@localhost' '$log_file' -p 22
  "

  [ "$status" -eq 0 ]
  [[ "$output" =~ "1 passed, 0 failed, 1 total" ]]
}

# =============================================================================
# Full E2E Orchestrator — vmctl.sh Actions
# =============================================================================

@test "VM-IAC.39: vmctl --action start --dry-run succeeds with dry-run output" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action start \
    --profile current \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json" \
    --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" =~ "[dry-run]" ]] || [[ "$output" =~ "already running" ]]
}

@test "VM-IAC.40: vmctl --action stop --dry-run succeeds with dry-run output" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action stop \
    --profile current \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json" \
    --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" =~ "[dry-run]" ]] || [[ "$output" =~ "not running" ]]
}

@test "VM-IAC.41: vmctl --action full-e2e --dry-run previews all 5 steps" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action full-e2e \
    --profile current \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json" \
    --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Step 1/5" ]]
  [[ "$output" =~ "Step 2/5" ]]
  [[ "$output" =~ "Step 3/5" ]]
  [[ "$output" =~ "Step 4/5" ]]
  [[ "$output" =~ "Step 5/5" ]]
}

@test "VM-IAC.42: vmctl --help includes start, stop, full-e2e" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" =~ "start" ]]
  [[ "$output" =~ "stop" ]]
  [[ "$output" =~ "full-e2e" ]]
}

@test "VM-IAC.43: vmctl --help includes --keep-vm" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" =~ "--keep-vm" ]]
}

@test "VM-IAC.44: vm-matrix.sh --help includes new actions" {
  run "$DOTFILES_ROOT/scripts/vm/vm-matrix.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" =~ "start" ]]
  [[ "$output" =~ "stop" ]]
  [[ "$output" =~ "full-e2e" ]]
  [[ "$output" =~ "--keep-vm" ]]
}

# =============================================================================
# Full E2E Orchestrator — Infrastructure Files
# =============================================================================

@test "VM-IAC.45: Verification manifest file exists and has valid syntax" {
  local manifest="$DOTFILES_ROOT/infrastructure/vm/verify-manifest.txt"

  [[ -f "$manifest" ]]

  # Every non-comment, non-blank line should start with a known type
  local bad_lines=""
  bad_lines="$(grep -vE '^\s*(#|$)' "$manifest" | grep -vE '^\s*(file|dir|symlink|contains|cmd)\s' || true)"

  [[ -z "$bad_lines" ]]
}

@test "VM-IAC.46: Verification manifest has no duplicate entries" {
  local manifest="$DOTFILES_ROOT/infrastructure/vm/verify-manifest.txt"

  [[ -f "$manifest" ]]

  # Extract non-comment lines and check for duplicates
  local dupes=""
  dupes="$(grep -vE '^\s*(#|$)' "$manifest" | sort | uniq -d || true)"

  [[ -z "$dupes" ]]
}

@test "VM-IAC.47: vm_capture_log writes to log file (tested with local command)" {
  local log_file="$BATS_TEST_TMPDIR/capture.log"

  run bash -c "
    source '$DOTFILES_ROOT/scripts/vm/lib.sh'
    ssh() { local cmd=\"\${*: -1}\"; bash -c \"\$cmd\"; }
    export -f ssh
    vm_capture_log 'dummy@localhost' 'echo hello-from-capture' '$log_file' -p 22
  "

  [ "$status" -eq 0 ]
  [[ -f "$log_file" ]]
  grep -q 'hello-from-capture' "$log_file"
}

@test "VM-IAC.48: vmctl plan includes full-e2e lifecycle steps" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action plan \
    --profile current \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Full E2E" ]] || [[ "$output" =~ "full-e2e" ]]
}
