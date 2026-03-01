#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/status_engine.sh"
source "$SCRIPT_DIR/lib_render.sh"

current_session_id="${1:-}"
current_session_name="${2:-}"

# Single tmux call to get all needed info
IFS=$'\t' read -r detect_session_id detect_session_name term_width status_bg < <(
    tmux display-message -p '#{session_id}	#{session_name}	#{client_width}	#{status-bg}' 2>/dev/null || echo ""
)

[[ -z "$current_session_id" ]] && current_session_id="$detect_session_id"
[[ -z "$current_session_name" ]] && current_session_name="$detect_session_name"
[[ -z "$status_bg" || "$status_bg" == "default" ]] && status_bg=black
term_width="${term_width:-100}"

inactive_bg="#3A3D45"
inactive_fg="#A7ACB8"
active_bg="#B8BB26"
active_fg="#1A1B26"
separator=""
left_cap=""
hollow_separator=" "
max_width=18

left_narrow_width=${TMUX_LEFT_NARROW_WIDTH:-80}
is_narrow=0
[[ "$term_width" =~ ^[0-9]+$ ]] && ((term_width < left_narrow_width)) && is_narrow=1

normalize_session_id() {
    local value="$1"
    value="${value#\$}"
    printf '%s' "$value"
}

trim_label() {
    local value="$1"
    if [[ "$value" =~ ^[0-9]+[:-](.*)$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '%s' "$value"
    fi
}

extract_index() {
    local value="$1"
    if [[ "$value" =~ ^([0-9]+)[:-].*$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf ''
    fi
}

session_robot_icon() {
    local sid="$1"
    local count
    count=$("$ENGINE" query count --scope session --id "$sid" --kind robot 2>/dev/null || echo 0)
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0
    icon_with_optional_superscript '🤖' "$count"
}

session_bell_icon() {
    local sid="$1"
    local count
    count=$("$ENGINE" query count --scope session --id "$sid" --kind bell 2>/dev/null || echo 0)
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0
    printf ' %s' "$(icon_with_optional_superscript '🔔' "$count")"
}

sessions=$(tmux list-sessions -F '#{session_id}::#{session_name}' 2>/dev/null || true)
if [[ -z "$sessions" ]]; then
    exit 0
fi

rendered=""
prev_bg=""
current_session_id_norm=$(normalize_session_id "$current_session_id")
current_session_trimmed=$(trim_label "$current_session_name")
while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    session_id="${entry%%::*}"
    name="${entry#*::}"
    [[ -z "$session_id" ]] && continue

    session_id_norm=$(normalize_session_id "$session_id")
    segment_bg="$inactive_bg"
    segment_fg="$inactive_fg"
    segment_attr="nobold"
    trimmed_name=$(trim_label "$name")
    is_current=0
    if [[ "$session_id" == "$current_session_id" || "$session_id_norm" == "$current_session_id_norm" || "$trimmed_name" == "$current_session_trimmed" ]]; then
        is_current=1
        segment_bg="$active_bg"
        segment_fg="$active_fg"
        segment_attr="bold"
    fi

    idx=$(extract_index "$name")
    if ((is_narrow == 1)); then
        if ((is_current == 1)); then
            label="$trimmed_name" # active: show TITLE (trim N-)
        else
            if [[ -n "$idx" ]]; then
                label="${idx}${hollow_separator}${trimmed_name}"
            else
                label="$trimmed_name"
            fi
        fi
    else
        if [[ -n "$idx" ]]; then
            label="${idx}${hollow_separator}${trimmed_name}"
        else
            label="$trimmed_name"
        fi
    fi
    if ((${#label} > max_width)); then
        label="${label:0:max_width-1}…"
    fi

    robot_icon=$(session_robot_icon "$session_id")
    bell_icon=$(session_bell_icon "$session_id")

    if [[ -z "$prev_bg" ]]; then
        rendered+="#[fg=${segment_bg},bg=${status_bg}]${left_cap}"
    else
        rendered+="#[fg=${prev_bg},bg=${segment_bg}]${separator}"
    fi
    rendered+="#[fg=${segment_fg},bg=${segment_bg},${segment_attr}] ${label} ${robot_icon}${bell_icon}"
    prev_bg="$segment_bg"
done <<< "$sessions"

if [[ -n "$prev_bg" ]]; then
    rendered+="#[fg=${prev_bg},bg=${status_bg}]${separator}"
fi

printf '%s' "${rendered}#[fg=${active_bg},bg=${status_bg},bold]  >>>  #[default]"
