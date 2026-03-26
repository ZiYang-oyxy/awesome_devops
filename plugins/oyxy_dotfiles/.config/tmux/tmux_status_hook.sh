#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSD="$SCRIPT_DIR/tmux_statusd.sh"

statusd_emit() {
    [[ -x "$STATUSD" ]] || return 0
    "$STATUSD" emit "$@" || true
}

resolve_pane_meta() {
    local pane_id="$1"
    tmux display-message -p -t "$pane_id" $'#{session_id}\t#{window_id}\t#{pane_id}\t#{client_tty}\t#{session_name}' 2>/dev/null || true
}

resolve_active_pane_meta() {
    local meta
    meta=$(tmux display-message -p $'#{pane_id}\t#{window_id}\t#{session_id}\t#{client_tty}' 2>/dev/null || true)
    if [[ -z "$meta" ]]; then
        meta=$(tmux list-clients -F $'#{pane_id}\t#{window_id}\t#{session_id}\t#{client_tty}' 2>/dev/null | awk 'NF { print; exit }' || true)
    fi
    printf '%s' "$meta"
}

ack_focus() {
    local pane_id="${1:-}"
    local window_id="${2:-}"
    local session_id="${3:-}"
    local pane_meta=""
    local client_tty=""

    if [[ -n "$pane_id" ]]; then
        pane_meta=$(resolve_pane_meta "$pane_id")
    fi

    if [[ -z "$pane_id" || -z "$pane_meta" ]]; then
        local active_meta
        active_meta=$(resolve_active_pane_meta)
        if [[ -n "$active_meta" ]]; then
            IFS=$'\t' read -r pane_id window_id session_id client_tty <<< "$active_meta"
            pane_meta=$(resolve_pane_meta "$pane_id")
        fi
    fi

    [[ -z "$pane_id" || -z "$pane_meta" ]] && return 0

    local resolved_sid resolved_wid resolved_pid resolved_tty
    IFS=$'\t' read -r resolved_sid resolved_wid resolved_pid resolved_tty _ <<< "$pane_meta"
    [[ -n "$resolved_pid" ]] && pane_id="$resolved_pid"
    [[ -z "$session_id" ]] && session_id="$resolved_sid"
    [[ -z "$window_id" ]] && window_id="$resolved_wid"
    [[ -z "$client_tty" ]] && client_tty="$resolved_tty"

    statusd_emit focus_changed \
        --pane "$pane_id" \
        --window "$window_id" \
        --session "$session_id" \
        --client-tty "$client_tty" \
        --source "tmux:focus"
}

pane_closed() {
    local pane_id="${1:-}"
    local window_id="${2:-}"
    local session_id="${3:-}"

    statusd_emit pane_closed \
        --pane "$pane_id" \
        --window "$window_id" \
        --session "$session_id" \
        --source "tmux:pane-closed"
    ack_focus "$@" || true
}

select_pane_by_payload() {
    local payload_cwd="$1"
    local panes="$2"
    local pane_id=""

    if [[ -n "$payload_cwd" ]]; then
        pane_id=$(printf '%s\n' "$panes" | awk -F '\t' -v cwd="$payload_cwd" '$2 == cwd && $3 == "1" { print $1; exit }')
        if [[ -z "$pane_id" ]]; then
            pane_id=$(printf '%s\n' "$panes" | awk -F '\t' -v cwd="$payload_cwd" '$2 == cwd { print $1; exit }')
        fi
    fi

    if [[ -z "$pane_id" ]]; then
        pane_id=$(printf '%s\n' "$panes" | awk -F '\t' '$3 == "1" { print $1; exit }')
    fi

    if [[ -z "$pane_id" ]]; then
        pane_id=$(printf '%s\n' "$panes" | awk -F '\t' 'NF { print $1; exit }')
    fi

    printf '%s' "$pane_id"
}

notify_done() {
    local args=("$@")
    local payload=""
    if ((${#args[@]} > 0)); then
        payload="${args[${#args[@]}-1]}"
    fi

    local payload_cwd=""
    if [[ -n "$payload" && -x "$(command -v jq || true)" ]]; then
        payload_cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)
    fi

    local pane_id="${TMUX_PANE:-}"
    if [[ -z "$pane_id" ]]; then
        local panes
        panes=$(tmux list-panes -a -F $'#{pane_id}\t#{pane_current_path}\t#{pane_active}' 2>/dev/null || true)
        [[ -z "$panes" ]] && return 0
        pane_id=$(select_pane_by_payload "$payload_cwd" "$panes")
    fi

    [[ -z "$pane_id" ]] && return 0

    local meta session_id window_id session_name client_tty
    meta=$(resolve_pane_meta "$pane_id")
    [[ -z "$meta" ]] && return 0

    IFS=$'\t' read -r session_id window_id pane_id client_tty session_name <<< "$meta"
    [[ -z "$session_id" || -z "$window_id" || -z "$pane_id" ]] && return 0
    [[ -z "$session_name" ]] && session_name="$session_id"

    local task_id="pane:${pane_id}"
    statusd_emit task_complete \
        --session "$session_id" \
        --window "$window_id" \
        --pane "$pane_id" \
        --task-id "$task_id" \
        --source "codex-notify"

    local active_client_panes
    active_client_panes=$(tmux list-clients -F '#{pane_id}' 2>/dev/null | awk 'NF { print }' | tr '\n' '\t' || true)
    if [[ "$active_client_panes" == *"${pane_id}"$'\t'* ]]; then
        statusd_emit task_ack \
            --session "$session_id" \
            --window "$window_id" \
            --pane "$pane_id" \
            --client-tty "$client_tty" \
            --task-id "$task_id" \
            --source "codex-notify"
    fi

    if command -v osascript >/dev/null 2>&1; then
        local notify_title notify_body notify_title_escaped notify_body_escaped
        notify_title='Codex task completed'
        notify_body="session: ${session_name}, window: ${window_id}, pane: ${pane_id}"

        notify_title_escaped=${notify_title//\\/\\\\}
        notify_title_escaped=${notify_title_escaped//\"/\\\"}
        notify_body_escaped=${notify_body//\\/\\\\}
        notify_body_escaped=${notify_body_escaped//\"/\\\"}

        osascript -e "display notification \"${notify_body_escaped}\" with title \"${notify_title_escaped}\"" >/dev/null 2>&1 || true
    fi
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        ack-focus)
            ack_focus "$@"
            ;;
        pane-closed)
            pane_closed "$@"
            ;;
        notify-done)
            notify_done "$@"
            ;;
        *)
            exit 0
            ;;
    esac
}

main "$@"
