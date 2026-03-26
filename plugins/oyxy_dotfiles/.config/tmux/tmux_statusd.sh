#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_STATE_DIR="${TMUX_STATUSD_STATE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/tmux-statusd}"

find_binary() {
    local name="$1"
    local candidate=""

    if candidate="$(command -v "$name" 2>/dev/null)"; then
        printf '%s\n' "$candidate"
        return 0
    fi

    for candidate in "$HOME/bin/$name" "$HOME/.local/bin/$name"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

ctl_bin() {
    find_binary "tmux-statusctl"
}

daemon_bin() {
    find_binary "tmux-statusd"
}

ensure_started() {
    local ctl daemon
    ctl="$(ctl_bin || true)"
    daemon="$(daemon_bin || true)"

    [[ -n "$ctl" && -n "$daemon" ]] || return 0

    if "$ctl" ping --state-dir "$DEFAULT_STATE_DIR" >/dev/null 2>&1; then
        return 0
    fi

    mkdir -p "$DEFAULT_STATE_DIR"
    nohup env \
        TMUX_STATUSD_STATE_DIR="$DEFAULT_STATE_DIR" \
        TMUX_STATUSD_TMUX_CONFIG_DIR="$SCRIPT_DIR" \
        "$daemon" serve --state-dir "$DEFAULT_STATE_DIR" >/dev/null 2>&1 &
}

emit() {
    local ctl
    ctl="$(ctl_bin || true)"
    [[ -n "$ctl" ]] || return 0

    ensure_started
    "$ctl" emit "$@" --state-dir "$DEFAULT_STATE_DIR" >/dev/null 2>&1 || true
}

query() {
    local ctl
    ctl="$(ctl_bin || true)"
    [[ -n "$ctl" ]] || return 1

    "$ctl" query "$@" --state-dir "$DEFAULT_STATE_DIR"
}

health() {
    local ctl
    ctl="$(ctl_bin || true)"
    [[ -n "$ctl" ]] || return 1

    "$ctl" health --state-dir "$DEFAULT_STATE_DIR"
}

ping() {
    local ctl
    ctl="$(ctl_bin || true)"
    [[ -n "$ctl" ]] || return 1

    "$ctl" ping --state-dir "$DEFAULT_STATE_DIR" >/dev/null 2>&1
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        ensure-started)
            ensure_started
            ;;
        emit)
            emit "$@"
            ;;
        query)
            query "$@"
            ;;
        health)
            health
            ;;
        ping)
            ping
            ;;
        *)
            exit 0
            ;;
    esac
}

main "$@"
