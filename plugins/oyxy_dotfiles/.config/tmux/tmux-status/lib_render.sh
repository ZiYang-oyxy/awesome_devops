#!/usr/bin/env bash
set -euo pipefail

to_superscript_digits() {
    local input="$1"
    local output=""
    local i ch
    [[ "$input" =~ ^[0-9]+$ ]] || input=0
    for ((i = 0; i < ${#input}; i++)); do
        ch="${input:i:1}"
        case "$ch" in
            0) output+="⁰" ;;
            1) output+="¹" ;;
            2) output+="²" ;;
            3) output+="³" ;;
            4) output+="⁴" ;;
            5) output+="⁵" ;;
            6) output+="⁶" ;;
            7) output+="⁷" ;;
            8) output+="⁸" ;;
            9) output+="⁹" ;;
        esac
    done
    printf '%s' "$output"
}

render_robot_suffix() {
    local scope="${1:-}"
    local count="$2"
    local superscript
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0
    superscript="$(to_superscript_digits "$count")"

    if [[ "$scope" == "window" ]]; then
        printf ' 🤖%s' "$superscript"
    else
        printf '  🤖%s' "$superscript"
    fi
}

render_bell_session_suffix() {
    local count="$1"
    local superscript
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0
    superscript="$(to_superscript_digits "$count")"
    printf '  🔔%s' "$superscript"
}

render_bell_window_suffix() {
    local count="$1"
    local superscript
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0
    superscript="$(to_superscript_digits "$count")"
    printf ' 🔔%s' "$superscript"
}

render_bell_pane_icon() {
    local flag="$1"
    if [[ "$flag" == "1" ]]; then
        printf '🔔¹'
    fi
}
