#!/usr/bin/env bash
set -euo pipefail

scope="${1:-}"
target_id="${2:-}"

[[ -z "$scope" || -z "$target_id" ]] && exit 0
[[ "$scope" != "session" && "$scope" != "window" ]] && exit 0

CACHE_FILE="/tmp/tmux-codex-pane-count.cache"
LOCK_DIR="/tmp/tmux-codex-pane-count.lock"
CACHE_MAX_AGE=1
LOCK_STALE_SECONDS=10

cache_fresh() {
    [[ -f "$CACHE_FILE" ]] || return 1
    local now_ts file_ts file_age
    now_ts=$(date +%s)
    if [[ "$OSTYPE" == darwin* ]]; then
        file_ts=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    else
        file_ts=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    fi
    [[ "$file_ts" =~ ^[0-9]+$ ]] || return 1
    file_age=$((now_ts - file_ts))
    ((file_age < CACHE_MAX_AGE))
}

build_cache() {
    local panes
    local tmp_file
    tmp_file=$(mktemp /tmp/tmux-codex-pane-count.cache.XXXXXX)
    panes=$(tmux list-panes -a -F '#{session_id}	#{window_id}	#{pane_current_command}' 2>/dev/null || true)

    if [[ -z "$panes" ]]; then
        : > "$tmp_file"
        mv "$tmp_file" "$CACHE_FILE"
        return 0
    fi

    printf '%s\n' "$panes" | awk -F '\t' '
        $3 ~ /^codex([[:space:]]|[-_]|$)/ {
            session_count[$1]++
            window_count[$2]++
        }
        END {
            for (sid in session_count) {
                printf "session\t%s\t%d\n", sid, session_count[sid]
            }
            for (wid in window_count) {
                printf "window\t%s\t%d\n", wid, window_count[wid]
            }
        }
    ' > "$tmp_file"
    mv "$tmp_file" "$CACHE_FILE"
}

refresh_cache_if_needed() {
    cache_fresh && return 0

    if [[ -d "$LOCK_DIR" ]]; then
        local now_ts lock_ts lock_age
        now_ts=$(date +%s)
        if [[ "$OSTYPE" == darwin* ]]; then
            lock_ts=$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0)
        else
            lock_ts=$(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
        fi
        if [[ "$lock_ts" =~ ^[0-9]+$ ]]; then
            lock_age=$((now_ts - lock_ts))
            if ((lock_age >= LOCK_STALE_SECONDS)); then
                rmdir "$LOCK_DIR" 2>/dev/null || true
            fi
        fi
    fi

    if mkdir "$LOCK_DIR" 2>/dev/null; then
        trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
        build_cache
        rmdir "$LOCK_DIR" 2>/dev/null || true
        trap - EXIT
    fi
}

read_count() {
    local value
    value=$(awk -F '\t' -v s="$scope" -v id="$target_id" '
        $1 == s && $2 == id {
            print $3
            found = 1
            exit
        }
        END {
            if (!found) {
                print 0
            }
        }
    ' "$CACHE_FILE" 2>/dev/null || echo 0)
    [[ "$value" =~ ^[0-9]+$ ]] || value=0
    printf '%s' "$value"
}

render_suffix() {
    local count="$1"
    if ((count <= 0)); then
        return 0
    fi
    printf ' %s󰅖🤖' "$count"
}

refresh_cache_if_needed
[[ -f "$CACHE_FILE" ]] || exit 0
count=$(read_count)
render_suffix "$count"
