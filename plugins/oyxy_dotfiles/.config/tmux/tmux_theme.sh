#!/usr/bin/env bash
set -euo pipefail

sync_color() {
    local theme
    theme=$(tmux show -gqv @theme_color 2>/dev/null || true)
    if [[ -z "$theme" ]]; then
        theme="#9A2600"
    fi
    tmux set -g @theme_color "$theme"
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
