#!/usr/bin/env bats
#
# Brewfile syntax smoke tests (no installation).
# Ensures entries follow known directives to catch format errors early.

load '../lib/test_helper'

@test "Brewfile exists in home" {
  [[ -f "$DOTFILES_SOURCE_DIR/Brewfile" ]]
}

@test "Brewfile contains only allowed directives and comments" {
  allowed='^(#|\s*$|brew |cask |mas |tap |vscode )'
  while IFS= read -r line; do
    [[ "$line" =~ $allowed ]]
  done < "$DOTFILES_SOURCE_DIR/Brewfile"
}
