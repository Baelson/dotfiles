#!/usr/bin/env bats
#
# Brewfile syntax smoke tests (no installation).
# Ensures entries follow known directives to catch format errors early.

load '../lib/test_helper'

@test "Brewfile template exists in home" {
  [[ -f "$DOTFILES_SOURCE_DIR/Brewfile.tmpl" ]]
}

@test "Brewfile template contains only allowed directives and comments" {
  allowed='^(#|\s*$|brew |cask |mas |tap |vscode |{{|\s*{{|- if|{{- end)'
  while IFS= read -r line; do
    # Skip template syntax lines for now - they'll be validated by chezmoi
    [[ "$line" =~ $allowed ]] || [[ "$line" =~ {{.*}} ]]
  done < "$DOTFILES_SOURCE_DIR/Brewfile.tmpl"
}

@test "Brewfile syntax validator catches invalid directives" {
  # Negative test: prove the validator above would reject bad input
  allowed='^(#|\s*$|brew |cask |mas |tap |vscode |{{|\s*{{|- if|{{- end)'
  bad_lines=("pip install numpy" "apt-get install curl" "invalid_directive foo")
  for bad_line in "${bad_lines[@]}"; do
    if [[ "$bad_line" =~ $allowed ]] || [[ "$bad_line" =~ {{.*}} ]]; then
      echo "Validator failed to reject: $bad_line" >&2
      return 1
    fi
  done
}
