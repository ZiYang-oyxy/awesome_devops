#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${TMUX_STATUS_STATE_FILE:-${TMUX_TRACKER_CACHE_FILE:-/tmp/tmux-status-state.v2.json}}"
STATE_LOCK_DIR="${TMUX_STATUS_LOCK_DIR:-/tmp/tmux-status-state.v2.lock}"
STATE_LOCK_STALE_SECONDS="${TMUX_STATUS_LOCK_STALE_SECONDS:-10}"

QUERY_CACHE_FILE="${TMUX_STATUS_QUERY_CACHE_FILE:-/tmp/tmux-status-query.v1.tsv}"
QUERY_CACHE_LOCK_DIR="${TMUX_STATUS_QUERY_LOCK_DIR:-/tmp/tmux-status-query.lock}"
QUERY_CACHE_TTL_MS="${TMUX_STATUS_QUERY_CACHE_TTL_MS:-300}"
QUERY_CACHE_LOCK_STALE_SECONDS="${TMUX_STATUS_QUERY_LOCK_STALE_SECONDS:-2}"

now_ts() {
    date +%s
}

now_ms() {
    perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1000'
}

sanitize_count() {
    local value="${1:-0}"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s' "$value"
    else
        printf '0'
    fi
}

lock_mtime() {
    local path="$1"
    if [[ "$OSTYPE" == darwin* ]]; then
        stat -f %m "$path" 2>/dev/null || echo 0
    else
        stat -c %Y "$path" 2>/dev/null || echo 0
    fi
}

lock_acquire_dir() {
    local lock_dir="$1"
    local stale_seconds="${2:-10}"
    local max_wait_loops="${3:-40}"
    local wait_loops=0

    while true; do
        if mkdir "$lock_dir" 2>/dev/null; then
            return 0
        fi

        if [[ -d "$lock_dir" ]]; then
            local now lock_ts age
            now=$(now_ts)
            lock_ts=$(lock_mtime "$lock_dir")
            if [[ "$lock_ts" =~ ^[0-9]+$ ]]; then
                age=$((now - lock_ts))
                if ((age >= stale_seconds)); then
                    rmdir "$lock_dir" 2>/dev/null || true
                    continue
                fi
            fi
        fi

        wait_loops=$((wait_loops + 1))
        if ((wait_loops >= max_wait_loops)); then
            return 1
        fi
        sleep 0.05
    done
}

lock_release_dir() {
    local lock_dir="$1"
    rmdir "$lock_dir" 2>/dev/null || true
}

state_default_json() {
    printf '{"version":2,"updated_at":0,"tasks":[]}\n'
}

state_bootstrap() {
    mkdir -p "$(dirname "$STATE_FILE")"
    if [[ -s "$STATE_FILE" ]]; then
        return 0
    fi

    local tmp_file
    tmp_file="${STATE_FILE}.tmp"
    state_default_json > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"
}

state_read_json() {
    if [[ -s "$STATE_FILE" ]]; then
        cat "$STATE_FILE" 2>/dev/null || state_default_json
    else
        state_default_json
    fi
}

state_write_json() {
    local json="$1"
    mkdir -p "$(dirname "$STATE_FILE")"
    local tmp_file
    tmp_file="${STATE_FILE}.tmp"
    printf '%s\n' "$json" > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"
}

state_prune_json() {
    local input_json="$1"
    local ts="${2:-$(now_ts)}"

    if ! command -v jq >/dev/null 2>&1; then
        printf '%s' "$input_json"
        return 0
    fi

    local all_panes
    all_panes=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | tr '\n' '\t' || true)

    printf '%s' "$input_json" | jq \
        --arg all_panes "$all_panes" \
        --argjson now "$ts" '
        .version = 2
        | .tasks = (
            (.tasks // [])
            | map(
                select(
                    (
                        .status == "completed"
                        and .acknowledged == true
                        and (.pane_id // "") != ""
                        and ($all_panes | contains((.pane_id // "") + "\t") | not)
                    ) | not
                )
            )
        )
        | .updated_at = $now
    '
}

query_cache_invalidate() {
    rm -f "$QUERY_CACHE_FILE" 2>/dev/null || true
}

query_cache_is_fresh() {
    [[ -s "$QUERY_CACHE_FILE" ]] || return 1
    [[ "$QUERY_CACHE_TTL_MS" =~ ^[0-9]+$ ]] || return 1

    local header
    header=$(sed -n '1p' "$QUERY_CACHE_FILE" 2>/dev/null || true)
    [[ "$header" =~ ^#ts_ms=([0-9]+)$ ]] || return 1

    local ts="${BASH_REMATCH[1]}"
    local now
    now=$(now_ms)
    [[ "$now" =~ ^[0-9]+$ ]] || return 1

    local age=$((now - ts))
    ((age >= 0 && age <= QUERY_CACHE_TTL_MS))
}

query_build_robot_lines() {
    tmux list-panes -a -F $'#{session_id}\t#{window_id}\t#{pane_id}\t#{pane_current_command}' 2>/dev/null | awk -F '\t' '
        function is_codex_command(cmd, normalized) {
            normalized = tolower(cmd)
            if (normalized == "codex") {
                return 1
            }
            if (index(normalized, "codex-") == 1) {
                return 1
            }
            if (index(normalized, "codex_") == 1) {
                return 1
            }
            return 0
        }

        {
            if (is_codex_command($4)) {
                if ($1 != "") {
                    session[$1]++
                }
                if ($2 != "") {
                    window[$2]++
                }
                if ($3 != "") {
                    pane[$3]++
                }
            }
        }

        END {
            for (k in session) {
                printf "session\t%s\t%d\n", k, session[k]
            }
            for (k in window) {
                printf "window\t%s\t%d\n", k, window[k]
            }
            for (k in pane) {
                printf "pane\t%s\t%d\n", k, pane[k]
            }
        }
    '
}

query_build_bell_lines() {
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    local state
    state=$(state_read_json)
    printf '%s' "$state" | jq -r '
        (.tasks // [])[]?
        | select(.status == "completed" and .acknowledged != true)
        | [(.session_id // ""), (.window_id // ""), (.pane_id // "")]
        | @tsv
    ' 2>/dev/null | awk -F '\t' '
        {
            if ($1 != "") {
                session[$1]++
            }
            if ($2 != "") {
                window[$2]++
            }
            if ($3 != "") {
                pane[$3]++
            }
        }

        END {
            for (k in session) {
                printf "session\t%s\t%d\n", k, session[k]
            }
            for (k in window) {
                printf "window\t%s\t%d\n", k, window[k]
            }
            for (k in pane) {
                printf "pane\t%s\t%d\n", k, pane[k]
            }
        }
    '
}

query_build_cache() {
    local now
    now=$(now_ms)
    [[ "$now" =~ ^[0-9]+$ ]] || now=0

    local tmp
    tmp="${QUERY_CACHE_FILE}.tmp"

    local robot_lines bell_lines merged_lines
    robot_lines=$(query_build_robot_lines 2>/dev/null || true)
    bell_lines=$(query_build_bell_lines 2>/dev/null || true)
    merged_lines=$(
        {
            if [[ -n "$robot_lines" ]]; then
                printf '%s\n' "$robot_lines" | awk -F '\t' 'NF>=3 { printf "R\t%s\t%s\t%s\n", $1, $2, $3 }'
            fi
            if [[ -n "$bell_lines" ]]; then
                printf '%s\n' "$bell_lines" | awk -F '\t' 'NF>=3 { printf "B\t%s\t%s\t%s\n", $1, $2, $3 }'
            fi
        } | awk -F '\t' '
            $1 == "R" {
                key = $2 FS $3
                robot[key] = $4 + 0
                seen[key] = 1
            }
            $1 == "B" {
                key = $2 FS $3
                bell[key] = $4 + 0
                seen[key] = 1
            }
            END {
                for (k in seen) {
                    split(k, arr, FS)
                    printf "%s\t%s\t%d\t%d\n", arr[1], arr[2], robot[k] + 0, bell[k] + 0
                }
            }
        ' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2
    )

    {
        printf '#ts_ms=%s\n' "$now"
        if [[ -n "$merged_lines" ]]; then
            printf '%s\n' "$merged_lines"
        fi
    } > "$tmp"

    mv "$tmp" "$QUERY_CACHE_FILE"
}

query_cache_ensure() {
    if query_cache_is_fresh; then
        return 0
    fi

    lock_acquire_dir "$QUERY_CACHE_LOCK_DIR" "$QUERY_CACHE_LOCK_STALE_SECONDS" 30 || return 0

    if ! query_cache_is_fresh; then
        query_build_cache || true
    fi

    lock_release_dir "$QUERY_CACHE_LOCK_DIR"
}

query_cached_count() {
    local scope="$1"
    local target_id="$2"
    local kind="$3"
    local column=3

    [[ "$kind" == "bell" ]] && column=4

    query_cache_ensure

    if [[ ! -s "$QUERY_CACHE_FILE" ]]; then
        printf '0'
        return 0
    fi

    awk -F '\t' -v scope="$scope" -v target="$target_id" -v col="$column" '
        NR > 1 && $1 == scope && $2 == target {
            print $col
            found = 1
            exit
        }
        END {
            if (!found) {
                print 0
            }
        }
    ' "$QUERY_CACHE_FILE" 2>/dev/null
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

    local ts
    ts=$(now_ts)

    lock_acquire_dir "$STATE_LOCK_DIR" "$STATE_LOCK_STALE_SECONDS" 40 || return 0
    state_bootstrap

    local state updated pruned
    state=$(state_read_json)
    updated=$(printf '%s' "$state" | jq \
        --arg sid "$session_id" \
        --arg wid "$window_id" \
        --arg pid "$pane_id" \
        --arg task_id "$task_id" \
        --arg source "$source_name" \
        --argjson now "$ts" '
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

    pruned=$(state_prune_json "$updated" "$ts" 2>/dev/null || printf '%s' "$updated")
    state_write_json "$pruned"

    lock_release_dir "$STATE_LOCK_DIR"
    query_cache_invalidate
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

    local ts
    ts=$(now_ts)

    lock_acquire_dir "$STATE_LOCK_DIR" "$STATE_LOCK_STALE_SECONDS" 40 || return 0
    state_bootstrap

    local state updated pruned
    state=$(state_read_json)
    updated=$(printf '%s' "$state" | jq \
        --arg pid "$pane_id" \
        --arg sid "$session_id" \
        --arg wid "$window_id" \
        --argjson now "$ts" '
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

    pruned=$(state_prune_json "$updated" "$ts" 2>/dev/null || printf '%s' "$updated")
    state_write_json "$pruned"

    lock_release_dir "$STATE_LOCK_DIR"
    query_cache_invalidate
}

run_gc_prune() {
    lock_acquire_dir "$STATE_LOCK_DIR" "$STATE_LOCK_STALE_SECONDS" 40 || return 0
    state_bootstrap

    local ts state pruned
    ts=$(now_ts)
    state=$(state_read_json)
    pruned=$(state_prune_json "$state" "$ts" 2>/dev/null || printf '%s' "$state")
    state_write_json "$pruned"

    lock_release_dir "$STATE_LOCK_DIR"
    query_cache_invalidate
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
        robot|bell)
            sanitize_count "$(query_cached_count "$scope" "$target_id" "$kind")"
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
        local bell_count
        bell_count=$(sanitize_count "$(query_cached_count "pane" "$target_id" "bell")")
        if ((bell_count > 0)); then
            printf '1'
        else
            printf '0'
        fi
    else
        printf '0'
    fi
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

    [[ "$scope" != "session" && "$scope" != "window" && "$scope" != "pane" ]] && return 0

    query_cache_ensure
    [[ -s "$QUERY_CACHE_FILE" ]] || return 0

    awk -F '\t' -v scope="$scope" 'NR > 1 && $1 == scope { printf "%s\t%s\t%s\n", $2, $3, $4 }' "$QUERY_CACHE_FILE"
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

    [[ -z "$scope" || -z "$target_id" ]] && {
        printf 'robot=0\tbell=0\n'
        return 0
    }

    local robot bell
    robot=$(sanitize_count "$(query_cached_count "$scope" "$target_id" "robot")")
    bell=$(sanitize_count "$(query_cached_count "$scope" "$target_id" "bell")")
    printf 'robot=%s\tbell=%s\n' "$robot" "$bell"
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
