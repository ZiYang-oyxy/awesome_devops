#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib_state.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib_query.sh"

sanitize_count() {
    local value="${1:-0}"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s' "$value"
    else
        printf '0'
    fi
}

event_complete() {
    local session_id=""
    local window_id=""
    local pane_id=""
    local task_id=""
    local source_name="codex-notify"

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

    [[ -z "$session_id" || -z "$window_id" || -z "$pane_id" ]] && return 0
    [[ -z "$task_id" ]] && task_id="pane:${pane_id}"

    local now_ts
    now_ts=$(state_now_ts)

    state_lock_acquire || return 0
    trap 'state_lock_release' EXIT
    state_bootstrap

    local state updated pruned
    state=$(state_read_json)
    updated=$(printf '%s' "$state" | jq \
        --arg sid "$session_id" \
        --arg wid "$window_id" \
        --arg pid "$pane_id" \
        --arg task_id "$task_id" \
        --arg source "$source_name" \
        --argjson now "$now_ts" '
        .version = 2
        | .tasks = (
            ((.tasks // []) | map(select((.task_id // "") != $task_id and (.pane_id // "") != $pid)))
            + [{
                task_id: $task_id,
                session_id: $sid,
                window_id: $wid,
                pane_id: $pid,
                status: "completed",
                acknowledged: false,
                updated_at: $now,
                source: $source
            }]
        )
        | .updated_at = $now
    ' 2>/dev/null || printf '%s' "$state")

    pruned=$(state_prune_json "$updated" "$now_ts" 2>/dev/null || printf '%s' "$updated")
    state_write_json "$pruned"
}

event_ack() {
    local pane_id=""
    local session_id=""
    local window_id=""

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
            *)
                shift
                ;;
        esac
    done

    [[ -z "$pane_id" ]] && return 0

    local now_ts
    now_ts=$(state_now_ts)

    state_lock_acquire || return 0
    trap 'state_lock_release' EXIT
    state_bootstrap

    local state updated pruned
    state=$(state_read_json)
    updated=$(printf '%s' "$state" | jq \
        --arg pid "$pane_id" \
        --arg sid "$session_id" \
        --arg wid "$window_id" \
        --argjson now "$now_ts" '
        .version = 2
        | .tasks = (
            (.tasks // [])
            | map(
                if (
                    .status == "completed"
                    and (.pane_id // "") == $pid
                    and (
                        ($sid != "" and $wid != "" and (.session_id // "") == $sid and (.window_id // "") == $wid)
                        or
                        ($sid == "" or $wid == "")
                    )
                ) then
                    .acknowledged = true | .updated_at = $now
                else
                    .
                end
            )
        )
        | .updated_at = $now
    ' 2>/dev/null || printf '%s' "$state")

    pruned=$(state_prune_json "$updated" "$now_ts" 2>/dev/null || printf '%s' "$updated")
    state_write_json "$pruned"
}

run_gc_prune() {
    state_lock_acquire || return 0
    trap 'state_lock_release' EXIT
    state_bootstrap
    local now_ts state pruned
    now_ts=$(state_now_ts)
    state=$(state_read_json)
    pruned=$(state_prune_json "$state" "$now_ts" 2>/dev/null || printf '%s' "$state")
    state_write_json "$pruned"
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

    [[ -z "$scope" || -z "$target_id" || -z "$kind" ]] && {
        printf '0'
        return 0
    }

    case "$kind" in
        robot)
            sanitize_count "$(query_robot_count "$scope" "$target_id")"
            ;;
        bell)
            sanitize_count "$(query_bell_count "$scope" "$target_id")"
            ;;
        *)
            printf '0'
            ;;
    esac
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

    if [[ "$scope" == "pane" && "$kind" == "bell" ]]; then
        query_bell_pane_flag "$target_id"
    else
        printf '0'
    fi
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
                *)
                    printf '0'
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
