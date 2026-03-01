#!/usr/bin/env bash
set -euo pipefail

lock_now_ts() {
    date +%s
}

lock_mtime() {
    local path="$1"
    if [[ "$OSTYPE" == darwin* ]]; then
        stat -f %m "$path" 2>/dev/null || echo 0
    else
        stat -c %Y "$path" 2>/dev/null || echo 0
    fi
}

lock_release_dir() {
    local lock_dir="$1"
    rmdir "$lock_dir" 2>/dev/null || true
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
            local now_ts lock_ts lock_age
            now_ts=$(lock_now_ts)
            lock_ts=$(lock_mtime "$lock_dir")
            if [[ "$lock_ts" =~ ^[0-9]+$ ]]; then
                lock_age=$((now_ts - lock_ts))
                if ((lock_age >= stale_seconds)); then
                    lock_release_dir "$lock_dir"
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
