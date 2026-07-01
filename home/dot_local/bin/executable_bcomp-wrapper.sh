#!/bin/bash
set -euo pipefail

is_ssh() {
    if [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ] || [ -n "${SSH_CONNECTION:-}" ]; then
        return 0
    fi
    return 1
}

bcomp_bin="${BCOMP_BIN:-/Applications/Beyond Compare.app/Contents/MacOS/bcomp}"
if is_ssh || [ ! -x "${bcomp_bin}" ]; then
    if command -v difft >/dev/null 2>&1; then
        exec difft "$@"
    elif command -v nvim >/dev/null 2>&1; then
        exec nvim -d "$@"
    else
        exec diff -u "$@"
    fi
else
    exec "${bcomp_bin}" "$@"
fi
