#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDER="$SCRIPT_DIR/tmux_status_render.sh"

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

strip_wrappers() {
    sed -E 's/\\\[|\\\]//g; s/%\{|%\}//g'
}

ansi_to_tmux_styles() {
    perl -Mstrict -Mwarnings -pe '
        my $base_fg = $ENV{STARSHIP_TMUX_BASE_FG} // "default";
        sub sgr_to_tmux {
            my ($seq) = @_;
            my @codes = split /;/, $seq;
            my $out = "";
            for (my $i = 0; $i < @codes; $i++) {
                my $c = $codes[$i];
                $c = 0 if !defined($c) || $c eq "";
                if ($c == 0) { $out .= "#[fg=$base_fg]#[nobold]"; next; }
                if ($c == 1) { $out .= "#[bold]"; next; }
                if ($c == 22) { $out .= "#[nobold]"; next; }
                if ($c == 39) { $out .= "#[fg=$base_fg]"; next; }
                if ($c >= 30 && $c <= 37) { $out .= "#[fg=colour" . ($c - 30) . "]"; next; }
                if ($c >= 90 && $c <= 97) { $out .= "#[fg=colour" . ($c - 90 + 8) . "]"; next; }
                if ($c == 38) {
                    my $mode = $codes[$i + 1] // "";
                    if ($mode eq "5") {
                        my $idx = $codes[$i + 2] // "";
                        if ($idx =~ /^\d+$/) { $out .= "#[fg=colour$idx]"; }
                        $i += 2;
                        next;
                    }
                    if ($mode eq "2") {
                        my ($r, $g, $b) = @codes[$i + 2, $i + 3, $i + 4];
                        if (defined($r) && defined($g) && defined($b) &&
                            $r =~ /^\d+$/ && $g =~ /^\d+$/ && $b =~ /^\d+$/) {
                            $out .= sprintf("#[fg=#%02X%02X%02X]", $r, $g, $b);
                        }
                        $i += 4;
                        next;
                    }
                }
            }
            return $out;
        }
        s/\e\[([0-9;]*)m/sgr_to_tmux($1)/ge;
    '
}

starship_title() {
    local pid="$1"
    local width="$2"
    local pane_path="$3"
    local pane_cmd="$4"

    if [[ -n "$pid" ]]; then
        local ps_line
        ps_line=$(ps e -p "$pid" -o command= 2>/dev/null || true)
        if [[ -n "$ps_line" ]]; then
            local venv conda_env conda_prefix
            venv=$(printf '%s' "$ps_line" | sed -n 's/.*[[:space:]]VIRTUAL_ENV=\([^[:space:]]*\).*/\1/p' | tail -n1)
            conda_env=$(printf '%s' "$ps_line" | sed -n 's/.*[[:space:]]CONDA_DEFAULT_ENV=\([^[:space:]]*\).*/\1/p' | tail -n1)
            conda_prefix=$(printf '%s' "$ps_line" | sed -n 's/.*[[:space:]]CONDA_PREFIX=\([^[:space:]]*\).*/\1/p' | tail -n1)
            [[ -n "$venv" ]] && export VIRTUAL_ENV="$venv"
            [[ -n "$conda_env" ]] && export CONDA_DEFAULT_ENV="$conda_env"
            [[ -n "$conda_prefix" ]] && export CONDA_PREFIX="$conda_prefix"
        fi
    fi

    local cfg
    cfg="${STARSHIP_TMUX_CONFIG:-$HOME/.config/starship-tmux.toml}"

    if command -v starship >/dev/null 2>&1; then
        (
            cd "$pane_path"
            STARSHIP_LOG=error STARSHIP_CONFIG="$cfg" \
                starship prompt --terminal-width "$width" | strip_wrappers | ansi_to_tmux_styles | tr -d '\n'
        ) || printf '%s — %s' "$pane_cmd" "${pane_path##*/}"
    else
        printf '%s — %s' "$pane_cmd" "${pane_path##*/}"
    fi
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

    local inner_width=$((width - 4))
    if [[ -n "$zoomed_prefix" ]]; then
        inner_width=$((inner_width - 2))
    fi
    if ((inner_width < 10)); then
        inner_width="$width"
    fi

    local title pane_icon title_plain
    title="$(STARSHIP_TMUX_BASE_FG="$text_color" starship_title "$pid" "$inner_width" "$pane_path" "$pane_cmd")"
    pane_icon="$("$RENDER" pane-icon "$pane_id" "$window_id" "$active" "$pane_cmd" 2>/dev/null || true)"
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
