#!/usr/bin/env zsh
# iterm-badge.sh — Set the iTerm2 badge text for the current tab
#
# Uses iTerm2's proprietary OSC 1337 SetBadgeFormat escape sequence.
# No-ops gracefully when not running under iTerm2 so it's safe to call
# from scripts that may run in other terminals (xterm, ssh'd sessions,
# cron, etc.) — silent no-op is preferred over noisy escape bytes.
#
# When invoked inside tmux, wraps the escape in tmux's DCS passthrough
# so it reaches the outer iTerm2 (requires `set -g allow-passthrough on`
# in tmux.conf — already configured in this repo).
#
# Usage:
#   iterm-badge.sh "text"
#   iterm-badge.sh -t|--text "text"
#   iterm-badge.sh -c|--clear
#   iterm-badge.sh -h|--help

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: iterm-badge.sh [OPTIONS] [TEXT]

Set the iTerm2 badge text (OSC 1337 SetBadgeFormat).

Options:
  -t, --text <text>   Badge text (same as positional)
  -c, --clear         Clear the badge
  -h, --help          Show this help

Examples:
  iterm-badge.sh "dotfiles"
  iterm-badge.sh --text "prod-db"
  iterm-badge.sh --clear
USAGE
}

main() {
    local text=""
    local clear=false

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
                clear=true
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

    # Silent no-op outside iTerm2 — the escape sequence would be ignored anyway
    # but printing it creates visible garbage in some terminals (e.g., vscode).
    if [[ "${TERM_PROGRAM:-}" != "iTerm.app" ]]; then
        return 0
    fi

    local encoded
    if [[ "${clear}" == true ]]; then
        encoded=""
    else
        encoded="$(printf '%s' "${text}" | base64)"
    fi

    # Inside tmux, wrap the OSC 1337 in tmux's DCS passthrough sequence
    # so it propagates to the outer terminal.
    if [[ -n "${TMUX:-}" ]]; then
        printf "\ePtmux;\e\e]1337;SetBadgeFormat=%s\a\e\\\\" "${encoded}"
    else
        printf "\e]1337;SetBadgeFormat=%s\a" "${encoded}"
    fi
}

main "$@"
