#!/usr/bin/env bash
set -euo pipefail

# Args: <active> <theme_color> <pane_pid> <pane_width> <pane_path> <pane_cmd> <window_zoomed_flag> <pane_id> <window_id>
active="${1:-0}"
theme_color="${2:-}"
pid="${3:-}"
width_raw="${4:-80}"
pane_path="${5:-$PWD}"
pane_cmd="${6:-}"
zoomed_flag="${7:-0}"
pane_id="${8:-}"
window_id="${9:-}"

if [[ -z "$theme_color" ]]; then
  theme_color="#9A2600"
fi

contrast_text_for_bg() {
  # Keep background unchanged; only compute readable foreground.
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
      # Approximate ANSI 16-color palette in xterm.
      local ansi=(
        "0,0,0" "205,0,0" "0,205,0" "205,205,0"
        "0,0,238" "205,0,205" "0,205,205" "229,229,229"
        "127,127,127" "255,0,0" "0,255,0" "255,255,0"
        "92,92,255" "255,0,255" "0,255,255" "255,255,255"
      )
      IFS=',' read -r r g b <<< "${ansi[$idx]}"
    elif ((idx >= 232)); then
      local v=$((8 + (idx - 232) * 10))
      r=$v; g=$v; b=$v
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

width="$width_raw"
if ! [[ "$width" =~ ^[0-9]+$ ]]; then
  width=80
fi

zoomed_prefix=""
if [[ "$zoomed_flag" == "1" ]]; then
  zoomed_prefix="⛶ "
fi

inner_width=$((width - 4))
if [[ -n "$zoomed_prefix" ]]; then
  inner_width=$((inner_width - 2))
fi
if ((inner_width < 10)); then
  inner_width="$width"
fi

title="$(STARSHIP_TMUX_BASE_FG="$text_color" "$HOME/.config/tmux/scripts/pane_starship_title.sh" "$pid" "$inner_width" "$pane_path" "$pane_cmd")"
pane_icon="$("$HOME/.config/tmux/tmux-status/pane_task_icon.sh" "$pane_id" "$window_id" "$active" "$pane_cmd" 2>/dev/null || true)"
if [[ -n "$pane_icon" ]]; then
  pane_icon="${pane_icon} "
fi
title_plain="$(printf '%s' "$title" | sed -E 's/#\[[^]]*\]//g')"

left_cap=""
right_cap=""
body=" #[fg=${text_color}]${text_style}${zoomed_prefix}${pane_icon}${title}#[fg=${text_color}] "
plain_body=" ${zoomed_prefix}${pane_icon}${title_plain} "
plain="${left_cap}${plain_body}${right_cap}"
content_len=${#plain}

if ((width <= content_len)); then
  pad_left=0
  pad_right=0
else
  pad_left=$(((width - content_len) / 2))
  pad_right=$((width - content_len - pad_left))
fi

fill_char='━'
make_fill() {
  local count="$1"
  local out=""
  local i
  for ((i = 0; i < count; i++)); do
    out+="$fill_char"
  done
  printf '%s' "$out"
}

pad_left_str="$(make_fill "$pad_left")"
pad_right_str="$(make_fill "$pad_right")"

printf '%s' "#[fg=${fill_color}]${pad_left_str}#[fg=${accent_color}]${left_cap}#[bg=${accent_color}]${body}#[bg=default]#[fg=${accent_color}]${right_cap}#[fg=${fill_color}]${pad_right_str}#[default]"
