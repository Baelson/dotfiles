#!/usr/bin/env bash
#
# ShellCheck for Chezmoi Templates
# =================================
#
# Renders .sh.tmpl files through chezmoi's template engine, then runs
# shellcheck on the pure shell output. This catches bugs that would be
# missed by running shellcheck directly on template files (which contain
# Go template directives that confuse the parser).
#
# Also checks plain .sh files in the chezmoi scripts directory.
#
# Usage:
#   ./scripts/test/shellcheck-templates.sh              # check all
#   ./scripts/test/shellcheck-templates.sh file1 file2  # check specific files
#
# Requires: shellcheck, chezmoi

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS_DIR="$DOTFILES_ROOT/home/.chezmoiscripts"

errors=0

check_rendered_template() {
    local tmpl="$1"
    local relpath="${tmpl#"$DOTFILES_ROOT"/}"

    # Render template through chezmoi, then shellcheck the output
    # Flags:
    #   --shell=bash   Closest supported dialect to zsh (shellcheck has no zsh support)
    #   --severity=warning  Skip style/info-level noise
    if ! chezmoi execute-template < "$tmpl" 2>/dev/null | shellcheck --shell=bash --severity=warning -; then
        echo "FAIL: $relpath"
        errors=$((errors + 1))
    fi
}

check_plain_script() {
    local script="$1"
    local relpath="${script#"$DOTFILES_ROOT"/}"

    if ! shellcheck --shell=bash --severity=warning "$script"; then
        echo "FAIL: $relpath"
        errors=$((errors + 1))
    fi
}

main() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "shellcheck not found — skipping template checks"
        exit 0
    fi

    if ! command -v chezmoi >/dev/null 2>&1; then
        echo "chezmoi not found — skipping template checks"
        exit 0
    fi

    if [[ $# -gt 0 ]]; then
        # Check specific files passed as arguments
        for f in "$@"; do
            if [[ "$f" == *.sh.tmpl ]]; then
                check_rendered_template "$f"
            elif [[ "$f" == *.sh ]]; then
                check_plain_script "$f"
            fi
        done
    else
        # Check all templates and plain scripts
        while IFS= read -r -d '' tmpl; do
            check_rendered_template "$tmpl"
        done < <(find "$SCRIPTS_DIR" -name '*.sh.tmpl' -print0 2>/dev/null)

        while IFS= read -r -d '' script; do
            check_plain_script "$script"
        done < <(find "$SCRIPTS_DIR" -name '*.sh' -not -name '*.sh.tmpl' -print0 2>/dev/null)
    fi

    if [[ $errors -gt 0 ]]; then
        echo "$errors file(s) failed shellcheck"
        exit 1
    fi
}

main "$@"
