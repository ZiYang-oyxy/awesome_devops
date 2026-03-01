#!/usr/bin/env bash
set -euo pipefail

session_id="$1"
[[ -z "$session_id" ]] && exit 0

tracker_client="$HOME/.config/agent-tracker/bin/tracker-client"
[[ ! -x "$tracker_client" ]] && exit 0

state=$("$tracker_client" state 2>/dev/null || true)
[[ -z "$state" ]] && exit 0

in_progress_count=$(echo "$state" | jq -r --arg sid "$session_id" '
  [
    (.tasks // [])[]?
    | select(.session_id == $sid and .status == "in_progress")
  ] | length
' 2>/dev/null || echo 0)
waiting_count=$(echo "$state" | jq -r --arg sid "$session_id" '
  [
    (.tasks // [])[]?
    | select(.session_id == $sid and .status == "completed" and .acknowledged != true)
  ] | length
' 2>/dev/null || echo 0)

[[ "$in_progress_count" =~ ^[0-9]+$ ]] || in_progress_count=0
[[ "$waiting_count" =~ ^[0-9]+$ ]] || waiting_count=0

if ((in_progress_count > 0)); then
  if ((in_progress_count == 1)); then
    printf ' ⏳'
  else
    printf ' ⏳(%s)' "$in_progress_count"
  fi
fi

if ((waiting_count > 0)); then
  if ((waiting_count == 1)); then
    printf ' 🔔'
  else
    printf ' 🔔(%s)' "$waiting_count"
  fi
fi
