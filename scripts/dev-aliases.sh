#!/usr/bin/env bash
# Developer convenience aliases for local CI commands
# Source this in your shell to get short commands for common tasks.

# Only define if make is available
if command -v make >/dev/null 2>&1; then
  alias ci='make ci'
  alias t='make test'
  alias pc='make precommit'
fi
