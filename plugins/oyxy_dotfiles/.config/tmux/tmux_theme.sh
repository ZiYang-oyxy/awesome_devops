#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSD="$SCRIPT_DIR/tmux_statusd.sh"

sync_color() {
    local theme
    theme=$(tmux show -gqv @theme_color 2>/dev/null || true)
    if [[ -z "$theme" ]]; then
        theme="#9A2600"
    fi
    tmux set -g @theme_color "$theme"
    if [[ -x "$STATUSD" ]]; then
        "$STATUSD" emit layout_changed --source "tmux:theme-sync" >/dev/null 2>&1 || true
    fi
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        sync-color)
            sync_color "$@"
            ;;
        *)
            exit 0
            ;;
    esac
}

main "$@"
