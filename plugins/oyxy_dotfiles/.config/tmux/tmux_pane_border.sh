#!/usr/bin/env bash
set -euo pipefail

contrast_text_for_bg() {
    local bg="${1:-}"
    local r g b

    if [[ "$bg" =~ ^#([0-9a-fA-F]{6})$ ]]; then
        local hex="${BASH_REMATCH[1]}"
        r=$((16#${hex:0:2}))
        g=$((16#${hex:2:2}))
        b=$((16#${hex:4:2}))
    elif [[ "$bg" =~ ^colour([0-9]{1,3})$ ]]; then
        local idx="${BASH_REMATCH[1]}"
        if ((idx < 0 || idx > 255)); then
            printf '%s' "#FFFFFF"
            return
        fi

        if ((idx < 16)); then
            local ansi=(
                "0,0,0" "205,0,0" "0,205,0" "205,205,0"
                "0,0,238" "205,0,205" "0,205,205" "229,229,229"
                "127,127,127" "255,0,0" "0,255,0" "255,255,0"
                "92,92,255" "255,0,255" "0,255,255" "255,255,255"
            )
            IFS=',' read -r r g b <<< "${ansi[$idx]}"
        elif ((idx >= 232)); then
            local v=$((8 + (idx - 232) * 10))
            r=$v
            g=$v
            b=$v
        else
            local n=$((idx - 16))
            local rr=$((n / 36))
            local gg=$(((n % 36) / 6))
            local bb=$((n % 6))
            local steps=(0 95 135 175 215 255)
            r=${steps[$rr]}
            g=${steps[$gg]}
            b=${steps[$bb]}
        fi
    else
        printf '%s' "#FFFFFF"
        return
    fi

    local y=$(((299 * r + 587 * g + 114 * b) / 1000))
    if ((y >= 145)); then
        printf '%s' "#111111"
    else
        printf '%s' "#FFFFFF"
    fi
}

collapse_home_text() {
    local input="${1:-}"
    local physical_home=""

    if [[ -n "${HOME:-}" ]]; then
        physical_home="$(cd "$HOME" 2>/dev/null && pwd -P || true)"
    fi

    INPUT_TEXT="$input" HOME_TEXT="${HOME:-}" PHYSICAL_HOME_TEXT="$physical_home" perl -e '
        use strict;
        use warnings;

        my $text = $ENV{INPUT_TEXT} // q{};
        my @homes = grep { defined($_) && $_ ne q{} } ($ENV{HOME_TEXT}, $ENV{PHYSICAL_HOME_TEXT});
        my %seen;
        @homes = grep { !$seen{$_}++ } @homes;
        for my $home (@homes) {
            $text =~ s/\Q$home\E(?=\/|$)/~/g;
        }
        print $text;
    '
}

simple_title() {
    local pane_path="$1"
    [[ -z "$pane_path" ]] && pane_path="~"

    collapse_home_text "$pane_path"
}

make_fill() {
    local count="$1"
    local out=""
    local i
    for ((i = 0; i < count; i++)); do
        out+="━"
    done
    printf '%s' "$out"
}

format_border() {
    local active="${1:-0}"
    local theme_color="${2:-#9A2600}"
    local pid="${3:-}"
    local width_raw="${4:-80}"
    local pane_path="${5:-$PWD}"
    local pane_cmd="${6:-}"
    local zoomed_flag="${7:-0}"
    local pane_id="${8:-}"
    local window_id="${9:-}"
    local pane_icon_raw="${10:-}"

    [[ -z "$theme_color" ]] && theme_color="#9A2600"

    local accent_color text_style text_color fill_color
    if [[ "$active" == "1" ]]; then
        accent_color="$theme_color"
        text_style="#[bold]"
        text_color="$(contrast_text_for_bg "$accent_color")"
        fill_color="$accent_color"
    else
        accent_color="colour244"
        text_style=""
        text_color="$(contrast_text_for_bg "$accent_color")"
        fill_color="colour18"
    fi

    local width="$width_raw"
    if ! [[ "$width" =~ ^[0-9]+$ ]]; then
        width=80
    fi

    local zoomed_prefix=""
    if [[ "$zoomed_flag" == "1" ]]; then
        zoomed_prefix="⛶ "
    fi

    local title pane_icon title_plain
    title="$(simple_title "$pane_path")"
    pane_icon="$pane_icon_raw"
    if [[ -n "$pane_icon" ]]; then
        pane_icon="${pane_icon} "
    fi

    title_plain="$(printf '%s' "$title" | sed -E 's/#\[[^]]*\]//g')"

    local left_cap=""
    local right_cap=""
    local body=" #[fg=${text_color}]${text_style}${zoomed_prefix}${pane_icon}${title}#[fg=${text_color}] "
    local plain_body=" ${zoomed_prefix}${pane_icon}${title_plain} "
    local plain="${left_cap}${plain_body}${right_cap}"
    local content_len=${#plain}

    local pad_left pad_right
    if ((width <= content_len)); then
        pad_left=0
        pad_right=0
    else
        pad_left=$(((width - content_len) / 2))
        pad_right=$((width - content_len - pad_left))
    fi

    local pad_left_str pad_right_str
    pad_left_str="$(make_fill "$pad_left")"
    pad_right_str="$(make_fill "$pad_right")"

    printf '%s' "#[fg=${fill_color}]${pad_left_str}#[fg=${accent_color}]${left_cap}#[bg=${accent_color}]${body}#[bg=default]#[fg=${accent_color}]${right_cap}#[fg=${fill_color}]${pad_right_str}#[default]"
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        format)
            format_border "$@"
            ;;
        *)
            exit 0
            ;;
    esac
}

main "$@"
