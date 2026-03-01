#!/usr/bin/env bash
set -euo pipefail

render_robot_suffix() {
    local scope="$1"
    local count="$2"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0

    if [[ "$scope" == "window" ]]; then
        printf ' %s󰅖🤖' "$count"
    else
        printf ' %s󰅖🤖' "$count"
    fi
}

render_bell_session_suffix() {
    local count="$1"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0
    printf ' %s󰅖🔔' "$count"
}

render_bell_window_suffix() {
    local count="$1"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0
    printf '%s󰅖🔔' "$count"
}

render_bell_pane_icon() {
    local flag="$1"
    if [[ "$flag" == "1" ]]; then
        printf '🔔'
    fi
}
