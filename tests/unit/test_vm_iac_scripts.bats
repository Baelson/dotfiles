#!/usr/bin/env bats

load '../lib/test_helper'

setup() {
  setup_common
}

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

@test "VM-IAC.2: init-matrix creates a writable local matrix file" {
  local output_file="$BATS_TEST_TMPDIR/macos-matrix.local.json"

  run "$DOTFILES_ROOT/scripts/vm/init-matrix.sh" \
    --output-file "$output_file"

  [ "$status" -eq 0 ]
  [[ -f "$output_file" ]]
}

@test "VM-IAC.3: vmctl exposes help output" {
  run "$DOTFILES_ROOT/scripts/vm/vmctl.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" =~ --action ]]
  [[ "$output" =~ run-e2e ]]
}

@test "VM-IAC.4: vmctl doctor reports missing tart with actionable guidance" {
  run env PATH='/usr/bin:/bin' "$DOTFILES_ROOT/scripts/vm/vmctl.sh" \
    --action doctor \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "backend 'tart' is not installed" ]]
  [[ "$output" =~ "Install tart manually from https://tart.run/" ]]
}

@test "VM-IAC.5: vm-matrix plan renders both current and beta workflows" {
  run "$DOTFILES_ROOT/scripts/vm/vm-matrix.sh" \
    --action plan \
    --matrix-file "$DOTFILES_ROOT/infrastructure/vm/macos-matrix.example.json"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Profile: current" ]]
  [[ "$output" =~ "Profile: beta" ]]
}
