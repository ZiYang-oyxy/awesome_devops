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

if [[ "$active" == "1" ]]; then
  accent_color="$theme_color"
  text_style="#[bold]"
  text_color="#FFFFFF"
  fill_color="$accent_color"
else
  accent_color="colour244"
  text_style=""
  text_color="#000000"
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

title="$("$HOME/.config/tmux/scripts/pane_starship_title.sh" "$pid" "$inner_width" "$pane_path" "$pane_cmd")"
pane_icon="$("$HOME/.config/tmux/tmux-status/pane_task_icon.sh" "$pane_id" "$window_id" "$active" "$pane_cmd" 2>/dev/null || true)"
if [[ -n "$pane_icon" ]]; then
  pane_icon="${pane_icon} "
fi

left_cap=""
right_cap=""
body=" ${zoomed_prefix}${pane_icon}${title} "
plain="${left_cap}${body}${right_cap}"
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

printf '%s' "#[fg=${fill_color}]${pad_left_str}#[fg=${accent_color}]${left_cap}#[bg=${accent_color}]#[fg=${text_color}]${text_style}${body}#[bg=default]#[fg=${accent_color}]${right_cap}#[fg=${fill_color}]${pad_right_str}#[default]"
