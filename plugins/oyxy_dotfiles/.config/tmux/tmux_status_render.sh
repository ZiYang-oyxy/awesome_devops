#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/tmux_status_engine.sh"

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

icon_with_optional_superscript() {
    local icon="$1"
    local count="$2"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0

    if ((count == 1)); then
        printf '%s' "$icon"
    else
        printf '%s%s' "$icon" "$(to_superscript_digits "$count")"
    fi
}

render_robot_suffix() {
    local scope="${1:-}"
    local count="${2:-0}"
    local icon
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0

    icon="$(icon_with_optional_superscript '🤖' "$count")"
    if [[ "$scope" == "window" ]]; then
        printf ' %s' "$icon"
    else
        printf '  %s' "$icon"
    fi
}

render_bell_window_suffix() {
    local count="${1:-0}"
    local icon
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0

    icon="$(icon_with_optional_superscript '🔔' "$count")"
    printf '%s' "$icon"
}

render_bell_session_suffix() {
    local count="${1:-0}"
    local icon
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    ((count > 0)) || return 0

    icon="$(icon_with_optional_superscript '🔔' "$count")"
    printf ' %s' "$icon"
}

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

summary_value() {
    local summary="$1"
    local key="$2"
    printf '%s\n' "$summary" | awk -v key="$key" -F '[=\t]' '
        {
            for (i = 1; i <= NF; i += 2) {
                if ($i == key && (i + 1) <= NF) {
                    print $(i + 1)
                    exit
                }
            }
        }
    '
}

batch_count() {
    local batch="$1"
    local target_id="$2"
    local kind="$3"
    local column=2

    [[ "$kind" == "bell" ]] && column=3

    printf '%s\n' "$batch" | awk -F '\t' -v target="$target_id" -v col="$column" '
        $1 == target {
            print $col
            found = 1
            exit
        }
        END {
            if (!found) {
                print 0
            }
        }
    '
}

render_left() {
    local current_session_id="${1:-}"
    local current_session_name="${2:-}"

    local detect_session_id detect_session_name term_width status_bg
    IFS=$'\t' read -r detect_session_id detect_session_name term_width status_bg < <(
        tmux display-message -p $'#{session_id}\t#{session_name}\t#{client_width}\t#{status-bg}' 2>/dev/null || echo ""
    )

    [[ -z "$current_session_id" ]] && current_session_id="$detect_session_id"
    [[ -z "$current_session_name" ]] && current_session_name="$detect_session_name"
    [[ -z "$status_bg" || "$status_bg" == "default" ]] && status_bg=black
    term_width="${term_width:-100}"

    local inactive_bg="#3A3D45"
    local inactive_fg="#A7ACB8"
    local active_bg="#B8BB26"
    local active_fg="#1A1B26"
    local separator=""
    local left_cap=""
    local hollow_separator=" "
    local max_width=18

    local left_narrow_width="${TMUX_LEFT_NARROW_WIDTH:-80}"
    local is_narrow=0
    if [[ "$term_width" =~ ^[0-9]+$ ]] && ((term_width < left_narrow_width)); then
        is_narrow=1
    fi

    local sessions
    sessions=$(tmux list-sessions -F '#{session_id}::#{session_name}' 2>/dev/null || true)
    [[ -z "$sessions" ]] && return 0

    local session_batch
    session_batch=$("$ENGINE" query batch --scope session 2>/dev/null || true)

    local rendered=""
    local prev_bg=""
    local current_session_id_norm current_session_trimmed
    current_session_id_norm="$(normalize_session_id "$current_session_id")"
    current_session_trimmed="$(trim_label "$current_session_name")"

    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue

        local session_id name
        session_id="${entry%%::*}"
        name="${entry#*::}"
        [[ -z "$session_id" ]] && continue

        local session_id_norm segment_bg segment_fg segment_attr trimmed_name is_current
        session_id_norm="$(normalize_session_id "$session_id")"
        segment_bg="$inactive_bg"
        segment_fg="$inactive_fg"
        segment_attr="nobold"
        trimmed_name="$(trim_label "$name")"
        is_current=0

        if [[ "$session_id" == "$current_session_id" || "$session_id_norm" == "$current_session_id_norm" || "$trimmed_name" == "$current_session_trimmed" ]]; then
            is_current=1
            segment_bg="$active_bg"
            segment_fg="$active_fg"
            segment_attr="bold"
        fi

        local idx label
        idx="$(extract_index "$name")"
        if ((is_narrow == 1)); then
            if ((is_current == 1)); then
                label="$trimmed_name"
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

        local robot_count bell_count robot_icon bell_icon
        robot_count="$(batch_count "$session_batch" "$session_id" robot)"
        bell_count="$(batch_count "$session_batch" "$session_id" bell)"
        [[ "$robot_count" =~ ^[0-9]+$ ]] || robot_count=0
        [[ "$bell_count" =~ ^[0-9]+$ ]] || bell_count=0

        robot_icon=""
        bell_icon=""
        if ((robot_count > 0)); then
            robot_icon="$(icon_with_optional_superscript '🤖' "$robot_count")"
        fi
        if ((bell_count > 0)); then
            bell_icon="$(render_bell_session_suffix "$bell_count")"
        fi

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
}

render_window_suffix() {
    local window_id="${1:-}"
    [[ -z "$window_id" ]] && return 0

    local summary robot_count bell_count
    summary=$("$ENGINE" query summary --scope window --id "$window_id" 2>/dev/null || echo 'robot=0	bell=0')
    robot_count="$(summary_value "$summary" robot)"
    bell_count="$(summary_value "$summary" bell)"
    [[ "$robot_count" =~ ^[0-9]+$ ]] || robot_count=0
    [[ "$bell_count" =~ ^[0-9]+$ ]] || bell_count=0

    if ((robot_count > 0)); then
        render_robot_suffix window "$robot_count"
    fi
    if ((bell_count > 0)); then
        render_bell_window_suffix "$bell_count"
    fi
}

render_pane_icon() {
    local pane_id="${1:-}"
    [[ -z "$pane_id" ]] && return 0

    local summary robot_count bell_count rendered_icon
    summary=$("$ENGINE" query summary --scope pane --id "$pane_id" 2>/dev/null || echo 'robot=0	bell=0')
    robot_count="$(summary_value "$summary" robot)"
    bell_count="$(summary_value "$summary" bell)"
    [[ "$robot_count" =~ ^[0-9]+$ ]] || robot_count=0
    [[ "$bell_count" =~ ^[0-9]+$ ]] || bell_count=0

    if ((robot_count > 0)); then
        rendered_icon+="$(icon_with_optional_superscript '🤖' "$robot_count")"
    fi
    if ((bell_count > 0)); then
        rendered_icon+="$(icon_with_optional_superscript '🔔' "$bell_count")"
    fi

    printf '%s' "$rendered_icon"
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        left)
            render_left "$@"
            ;;
        window-suffix)
            render_window_suffix "$@"
            ;;
        pane-icon)
            render_pane_icon "$@"
            ;;
        *)
            exit 0
            ;;
    esac
}

main "$@"
