#!/usr/bin/env bats
#
# Security sanity checks to prevent accidental secret leakage in repo.

load '../lib/test_helper'

@test "No unencrypted SSH private keys tracked" {
  # Fail if typical private key names exist without .age encryption
  run bash -c "find \"$DOTFILES_SOURCE_DIR/dot_ssh\" -maxdepth 1 -type f \
    \( -name 'id_rsa' -o -name 'id_ed25519' -o -name 'known_hosts' \) 2>/dev/null | wc -l | tr -d '[:space:]'"
  [ "$status" -eq 0 ]
  [[ "$output" == 0 ]]
}

@test "Encrypted SSH materials are .age files only" {
  run bash -c "find \"$DOTFILES_SOURCE_DIR/dot_ssh\" -type f -name 'encrypted_*' ! -name '*.age' 2>/dev/null | wc -l | tr -d '[:space:]'"
  [ "$status" -eq 0 ]
  [[ "$output" == 0 ]]
}
