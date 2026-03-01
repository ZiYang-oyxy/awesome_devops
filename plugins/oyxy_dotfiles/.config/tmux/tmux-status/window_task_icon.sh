#!/usr/bin/env bash
set -euo pipefail

window_id="$1"
[[ -z "$window_id" ]] && exit 0

CACHE_FILE="/tmp/tmux-tracker-cache.json"
[[ ! -f "$CACHE_FILE" ]] && exit 0

state=$(cat "$CACHE_FILE" 2>/dev/null || true)
[[ -z "$state" ]] && exit 0

count=$(echo "$state" | jq -r --arg wid "$window_id" '
  [
    (.tasks // [])[]?
    | select(.window_id == $wid and .status == "completed" and .acknowledged != true)
  ] | length
' 2>/dev/null || echo 0)
[[ "$count" =~ ^[0-9]+$ ]] || count=0

if ((count <= 0)); then
  exit 0
fi
printf '%s󰅖🔔' "$count"
