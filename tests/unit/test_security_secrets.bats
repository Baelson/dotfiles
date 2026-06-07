#!/usr/bin/env bats
#
# Security sanity checks to prevent accidental secret leakage in repo.

load '../lib/test_helper'

@test "No unencrypted SSH private keys tracked" {
  # Fail if typical private key names exist without .age encryption
  run bash -c "find \"$DOTFILES_SOURCE_DIR/private_dot_ssh\" -maxdepth 1 -type f \
    \( -name 'id_rsa' -o -name 'id_ed25519' -o -name 'known_hosts' \) 2>/dev/null | wc -l | tr -d '[:space:]'"
  [ "$status" -eq 0 ]
  [[ "$output" == 0 ]]
}

@test "Encrypted SSH materials are .age files only" {
  run bash -c "find \"$DOTFILES_SOURCE_DIR/private_dot_ssh\" -type f -name 'encrypted_*' ! -name '*.age' 2>/dev/null | wc -l | tr -d '[:space:]'"
  [ "$status" -eq 0 ]
  [[ "$output" == 0 ]]
}

@test "No unencrypted sensitive files in private_Library" {
  # Private key and license files in private_Library should be age-encrypted
  # Excludes keybindings.json and other non-secret files matching *key*
  run bash -c "find \"$DOTFILES_SOURCE_DIR\" -path '*/private_Library/*' -type f \
    \( -name 'id_*' -o -name '*.pem' -o -name '*.p12' -o -name 'License.DaisyDisk' \) \
    ! -name '*.age' 2>/dev/null | wc -l | tr -d '[:space:]'"
  [ "$status" -eq 0 ]
  [[ "$output" == 0 ]]
}

@test "Age-encrypted files actually exist in repository" {
  # Prove the security tests aren't vacuous — encrypted files must be present
  # Match '*encrypted_*' (not 'encrypted_*'): all ssh blobs use the create_encrypted_* prefix
  # (the create_ create-if-absent rename); a name-START glob 'encrypted_*' misses them.
  run bash -c "find \"$DOTFILES_ROOT\" -name '*encrypted_*' -name '*.age' 2>/dev/null | wc -l | tr -d '[:space:]'"
  [ "$status" -eq 0 ]
  [[ "$output" -ge 1 ]]
}
