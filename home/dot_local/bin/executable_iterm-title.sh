#!/usr/bin/env zsh
# iterm-title.sh — Set the terminal tab/window title
#
# Uses OSC 0 (`\e]0;TEXT\a`), which iTerm2, xterm, GNOME Terminal, and
# most modern emulators honor. Unlike the badge, this is not iTerm2-
# specific, so there's no terminal-program guard. Inside tmux, wrapping
# in the DCS passthrough forwards the sequence to the outer terminal
# (requires `set -g allow-passthrough on` in tmux.conf).
#
# Setting a title via OSC 0 also overrides tmux's automatic-rename for
# the current window until tmux itself rewrites it — fine for the
# launcher's "Claude — <session>" use case; cosmetic otherwise.
#
# Usage:
#   iterm-title.sh "text"
#   iterm-title.sh -t|--text "text"
#   iterm-title.sh -c|--clear
#   iterm-title.sh -h|--help

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: iterm-title.sh [OPTIONS] [TEXT]

Set the terminal tab/window title (OSC 0).

Options:
  -t, --text <text>   Title text (same as positional)
  -c, --clear         Clear the title (empty string)
  -h, --help          Show this help

Examples:
  iterm-title.sh "Claude — dotfiles"
  iterm-title.sh --text "prod-deploy"
  iterm-title.sh --clear
USAGE
}

main() {
    local text=""

    while (( $# > 0 )); do
        case "$1" in
            -t|--text)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --text requires a value" >&2
                    exit 1
                fi
                text="$2"
                shift 2
                ;;
            -c|--clear)
                text=""
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
            *)
                text="$1"
                shift
                ;;
        esac
    done

    if [[ -n "${TMUX:-}" ]]; then
        printf "\ePtmux;\e\e]0;%s\a\e\\\\" "${text}"
    else
        printf "\e]0;%s\a" "${text}"
    fi
}

main "$@"
