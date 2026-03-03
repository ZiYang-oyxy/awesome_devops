#!/usr/bin/env bash
set -euo pipefail

run_tmux() {
    local output
    if ! output=$(tmux "$@" 2>&1); then
        tmux display-message "tmux-layout: tmux $* failed: ${output}"
        exit 1
    fi
    printf '%s' "$output"
}

build_layout() {
    local dir="$1"

    local pane_count=0
    local id1="" id2=""
    local top1=0 top2=0
    local left1=0 left2=0
    local path1="" path2=""

    while IFS='|' read -r pid ptop pleft ppath; do
        case "$pane_count" in
            0)
                id1="$pid"
                top1="$ptop"
                left1="$pleft"
                path1="$ppath"
                ;;
            1)
                id2="$pid"
                top2="$ptop"
                left2="$pleft"
                path2="$ppath"
                ;;
        esac
        pane_count=$((pane_count + 1))
    done < <(tmux list-panes -F "#{pane_id}|#{pane_top}|#{pane_left}|#{pane_current_path}")

    if [[ "$pane_count" -ne 2 ]]; then
        tmux display-message "tmux-layout build expects exactly 2 panes"
        return 0
    fi

    local top_id="" bottom_id="" top_path=""
    local left_id="" right_id="" left_path=""

    if [[ "$top1" -le "$top2" ]]; then
        top_id="$id1"
        top_path="$path1"
        bottom_id="$id2"
    else
        top_id="$id2"
        top_path="$path2"
        bottom_id="$id1"
    fi

    if [[ "$left1" -le "$left2" ]]; then
        left_id="$id1"
        left_path="$path1"
        right_id="$id2"
    else
        left_id="$id2"
        left_path="$path2"
        right_id="$id1"
    fi

    ensure_horizontal() {
        if [[ "$top1" -ne "$top2" ]]; then
            tmux display-message "tmux-layout ${dir} expects horizontal panes"
            return 1
        fi
        return 0
    }

    local new_id=""
    case "$dir" in
        right)
            new_id=$(run_tmux split-window -P -F '#{pane_id}' -h -c "$top_path" -t "$top_id")
            run_tmux join-pane -v -s "$bottom_id" -t "$top_id" >/dev/null
            run_tmux select-pane -t "$new_id" >/dev/null
            ;;
        left)
            new_id=$(run_tmux split-window -P -F '#{pane_id}' -h -b -c "$top_path" -t "$top_id")
            run_tmux join-pane -v -s "$bottom_id" -t "$top_id" >/dev/null
            run_tmux select-pane -t "$new_id" >/dev/null
            ;;
        up)
            ensure_horizontal || return 0
            run_tmux break-pane -d -s "$right_id" >/dev/null
            run_tmux select-pane -t "$left_id" >/dev/null
            new_id=$(run_tmux split-window -P -F '#{pane_id}' -v -b -c "$left_path" -t "$left_id")
            run_tmux join-pane -h -s "$right_id" -t "$left_id" >/dev/null
            run_tmux select-pane -t "$new_id" >/dev/null
            ;;
        down)
            ensure_horizontal || return 0
            run_tmux break-pane -d -s "$right_id" >/dev/null
            run_tmux select-pane -t "$left_id" >/dev/null
            new_id=$(run_tmux split-window -P -F '#{pane_id}' -v -c "$left_path" -t "$left_id")
            run_tmux join-pane -h -s "$right_id" -t "$left_id" >/dev/null
            run_tmux select-pane -t "$new_id" >/dev/null
            ;;
        *)
            tmux display-message "tmux-layout unknown direction: ${dir}"
            return 1
            ;;
    esac
}

toggle_orientation() {
    local info
    info=$(tmux list-panes -F '#{pane_id}|#{pane_top}|#{pane_left}')

    local pane_ids=()
    local pane_tops=()
    local pane_lefts=()
    while IFS='|' read -r pid top left; do
        [[ -z "$pid" ]] && continue
        pane_ids+=("$pid")
        pane_tops+=("$top")
        pane_lefts+=("$left")
    done <<EOF
$info
EOF

    if [[ "${#pane_ids[@]}" -ne 2 ]]; then
        tmux display-message "tmux-layout toggle needs exactly 2 panes"
        return 0
    fi

    local top_a="${pane_tops[0]}"
    local top_b="${pane_tops[1]}"
    local left_a="${pane_lefts[0]}"
    local left_b="${pane_lefts[1]}"

    if [[ "$top_a" == "$top_b" && "$left_a" != "$left_b" ]]; then
        tmux select-layout even-vertical
    elif [[ "$left_a" == "$left_b" && "$top_a" != "$top_b" ]]; then
        tmux select-layout even-horizontal
    else
        tmux select-layout tiled
    fi
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        build)
            local direction="${1:-}"
            [[ -z "$direction" ]] && {
                tmux display-message "tmux-layout build requires direction"
                exit 1
            }
            build_layout "$direction"
            ;;
        toggle)
            toggle_orientation
            ;;
        *)
            exit 0
            ;;
    esac
}

main "$@"
