#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSD="$SCRIPT_DIR/tmux_statusd.sh"

statusd_query() {
    [[ -x "$STATUSD" ]] || return 1
    "$STATUSD" query "$@"
}

statusd_emit() {
    [[ -x "$STATUSD" ]] || return 1
    "$STATUSD" emit "$@"
}

query_count() {
    local scope=""
    local target_id=""
    local kind=""

    while (($# > 0)); do
        case "$1" in
            --scope)
                scope="${2:-}"
                shift 2
                ;;
            --id)
                target_id="${2:-}"
                shift 2
                ;;
            --kind)
                kind="${2:-}"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$scope" || -z "$target_id" || -z "$kind" ]]; then
        printf '0\n'
        return 0
    fi

    statusd_query count --scope "$scope" --id "$target_id" --kind "$kind" 2>/dev/null || printf '0\n'
}

query_flag() {
    local scope=""
    local target_id=""
    local kind=""

    while (($# > 0)); do
        case "$1" in
            --scope)
                scope="${2:-}"
                shift 2
                ;;
            --id)
                target_id="${2:-}"
                shift 2
                ;;
            --kind)
                kind="${2:-}"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$scope" || -z "$target_id" || -z "$kind" ]]; then
        printf '0\n'
        return 0
    fi

    statusd_query flag --scope "$scope" --id "$target_id" --kind "$kind" 2>/dev/null || printf '0\n'
}

query_batch() {
    local scope=""

    while (($# > 0)); do
        case "$1" in
            --scope)
                scope="${2:-}"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    [[ "$scope" == "session" || "$scope" == "window" || "$scope" == "pane" ]] || return 0
    statusd_query batch --scope "$scope" 2>/dev/null || true
}

query_summary() {
    local scope=""
    local target_id=""

    while (($# > 0)); do
        case "$1" in
            --scope)
                scope="${2:-}"
                shift 2
                ;;
            --id)
                target_id="${2:-}"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$scope" || -z "$target_id" ]]; then
        printf 'robot=0\tbell=0\n'
        return 0
    fi

    statusd_query summary --scope "$scope" --id "$target_id" 2>/dev/null || printf 'robot=0\tbell=0\n'
}

event_complete() {
    local session_id=""
    local window_id=""
    local pane_id=""
    local task_id=""
    local source_name="tmux-status-engine:complete"

    while (($# > 0)); do
        case "$1" in
            --session-id)
                session_id="${2:-}"
                shift 2
                ;;
            --window-id)
                window_id="${2:-}"
                shift 2
                ;;
            --pane-id)
                pane_id="${2:-}"
                shift 2
                ;;
            --task-id)
                task_id="${2:-}"
                shift 2
                ;;
            --source)
                source_name="${2:-}"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    [[ -n "$session_id" && -n "$window_id" && -n "$pane_id" ]] || return 0
    [[ -n "$task_id" ]] || task_id="pane:${pane_id}"

    statusd_emit task_complete \
        --session "$session_id" \
        --window "$window_id" \
        --pane "$pane_id" \
        --task-id "$task_id" \
        --source "$source_name" >/dev/null 2>&1 || true
}

event_ack() {
    local pane_id=""
    local session_id=""
    local window_id=""
    local source_name="tmux-status-engine:ack"

    while (($# > 0)); do
        case "$1" in
            --pane-id)
                pane_id="${2:-}"
                shift 2
                ;;
            --session-id)
                session_id="${2:-}"
                shift 2
                ;;
            --window-id)
                window_id="${2:-}"
                shift 2
                ;;
            --source)
                source_name="${2:-}"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    [[ -n "$pane_id" ]] || return 0

    statusd_emit task_ack \
        --pane "$pane_id" \
        --session "$session_id" \
        --window "$window_id" \
        --task-id "pane:${pane_id}" \
        --source "$source_name" >/dev/null 2>&1 || true
}

run_gc_prune() {
    statusd_emit cache_gc --source "tmux-status-engine:gc" >/dev/null 2>&1 || true
}

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        event)
            case "${1:-}" in
                complete)
                    shift || true
                    event_complete "$@"
                    ;;
                ack)
                    shift || true
                    event_ack "$@"
                    ;;
                *)
                    exit 0
                    ;;
            esac
            ;;
        query)
            case "${1:-}" in
                count)
                    shift || true
                    query_count "$@"
                    ;;
                flag)
                    shift || true
                    query_flag "$@"
                    ;;
                batch)
                    shift || true
                    query_batch "$@"
                    ;;
                summary)
                    shift || true
                    query_summary "$@"
                    ;;
                *)
                    printf '0\n'
                    ;;
            esac
            ;;
        gc)
            if [[ "${1:-}" == "prune" ]]; then
                run_gc_prune
            fi
            ;;
        *)
            exit 0
            ;;
    esac
}

main "$@"
