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
