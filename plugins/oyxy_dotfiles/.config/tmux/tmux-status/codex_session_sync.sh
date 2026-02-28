#!/usr/bin/env bash
set -euo pipefail

CACHE_FILE="${TMUX_TRACKER_CACHE_FILE:-/tmp/tmux-tracker-cache.json}"
STATE_FILE="/tmp/tmux-codex-session-sync.state"
CODEX_SESSIONS_DIR="${CODEX_HOME:-$HOME/.codex}/sessions"

[[ -d "$CODEX_SESSIONS_DIR" ]] || exit 0

if [[ ! -f "$CACHE_FILE" ]]; then
  printf '{"tasks":[]}\n' > "$CACHE_FILE"
fi

state_bootstrap=0
if [[ ! -f "$STATE_FILE" ]]; then
  printf '{"offsets":{},"cwd_by_file":{}}\n' > "$STATE_FILE"
  state_bootstrap=1
fi

cache_json=$(cat "$CACHE_FILE" 2>/dev/null || true)
[[ -z "$cache_json" ]] && cache_json='{"tasks":[]}'
state_json=$(cat "$STATE_FILE" 2>/dev/null || true)
[[ -z "$state_json" ]] && state_json='{"offsets":{},"cwd_by_file":{}}'

update_state_kv() {
  local key="$1"
  local value="$2"
  state_json=$(printf '%s' "$state_json" | jq --arg k "$key" --arg v "$value" '.cwd_by_file[$k]=$v')
}

update_state_offset() {
  local key="$1"
  local value="$2"
  state_json=$(printf '%s' "$state_json" | jq --arg k "$key" --argjson v "$value" '.offsets[$k]=$v')
}

get_state_offset() {
  local key="$1"
  printf '%s' "$state_json" | jq -r --arg k "$key" '.offsets[$k] // 0'
}

get_state_cwd() {
  local key="$1"
  printf '%s' "$state_json" | jq -r --arg k "$key" '.cwd_by_file[$k] // empty'
}

resolve_pane_for_cwd() {
  local cwd="$1"
  local current_sid
  current_sid=$(tmux display-message -p '#{session_id}' 2>/dev/null || true)
  local pane
  pane=$(tmux list-panes -a -F '#{pane_id}	#{session_id}	#{pane_current_path}	#{pane_current_command}	#{pane_active}' 2>/dev/null \
    | awk -F '\t' -v c="$cwd" -v sid="$current_sid" '$2==sid && $3==c && ($4=="node" || $4=="codex") && $5=="1"{print $1; exit}')
  if [[ -z "$pane" ]]; then
    pane=$(tmux list-panes -a -F '#{pane_id}	#{session_id}	#{pane_current_path}	#{pane_current_command}' 2>/dev/null \
      | awk -F '\t' -v c="$cwd" -v sid="$current_sid" '$2==sid && $3==c && ($4=="node" || $4=="codex"){print $1; exit}')
  fi
  if [[ -z "$pane" ]]; then
    pane=$(tmux list-panes -a -F '#{pane_id}	#{pane_current_path}	#{pane_current_command}	#{pane_active}' 2>/dev/null \
      | awk -F '\t' -v c="$cwd" '$2==c && ($3=="node" || $3=="codex") && $4=="1"{print $1; exit}')
  fi
  if [[ -z "$pane" ]]; then
    pane=$(tmux list-panes -a -F '#{pane_id}	#{pane_current_path}	#{pane_current_command}' 2>/dev/null \
      | awk -F '\t' -v c="$cwd" '$2==c && ($3=="node" || $3=="codex"){print $1; exit}')
  fi
  if [[ -z "$pane" ]]; then
    pane=$(tmux list-panes -a -F '#{pane_id}	#{session_id}	#{pane_current_path}	#{pane_active}' 2>/dev/null \
      | awk -F '\t' -v c="$cwd" -v sid="$current_sid" '$2==sid && $3==c && $4=="1"{print $1; exit}')
  fi
  if [[ -z "$pane" ]]; then
    pane=$(tmux list-panes -a -F '#{pane_id}	#{pane_current_path}' 2>/dev/null \
      | awk -F '\t' -v c="$cwd" '$2==c{print $1; exit}')
  fi
  printf '%s' "$pane"
}

apply_task_complete() {
  local turn_id="$1"
  local cwd="$2"
  [[ -z "$turn_id" || -z "$cwd" ]] && return 0

  local pane_id
  pane_id=$(resolve_pane_for_cwd "$cwd")
  [[ -z "$pane_id" ]] && return 0

  local meta
  meta=$(tmux display-message -p -t "$pane_id" '#{session_id}	#{window_id}	#{pane_id}' 2>/dev/null || true)
  [[ -z "$meta" ]] && return 0

  local sid wid pid
  IFS=$'\t' read -r sid wid pid <<< "$meta"
  [[ -z "$sid" || -z "$wid" || -z "$pid" ]] && return 0

  local now_ts
  now_ts=$(date +%s)
  local task_id="turn:${turn_id}"

  cache_json=$(printf '%s' "$cache_json" | jq \
    --arg task_id "$task_id" \
    --arg sid "$sid" \
    --arg wid "$wid" \
    --arg pid "$pid" \
    --arg cwd "$cwd" \
    --argjson now "$now_ts" '
    .tasks = (
      ((.tasks // []) | map(select((.task_id // "") != $task_id)))
      + [{
        task_id: $task_id,
        session_id: $sid,
        window_id: $wid,
        pane_id: $pid,
        cwd: $cwd,
        status: "completed",
        acknowledged: false,
        updated_at: $now,
        source: "codex-session-log"
      }]
    )
  ')
}

# Only scan recent rollout files to keep this fast.
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  [[ -f "$file" ]] || continue

  size=$(wc -c < "$file" | tr -d ' ')
  offset=$(get_state_offset "$file")
  [[ "$offset" =~ ^[0-9]+$ ]] || offset=0
  if (( size < offset )); then
    offset=0
  fi

  cwd=$(get_state_cwd "$file")
  if [[ -z "$cwd" ]]; then
    cwd=$(head -n 1 "$file" 2>/dev/null | jq -r '.payload.cwd // empty' 2>/dev/null || true)
    [[ -n "$cwd" ]] && update_state_kv "$file" "$cwd"
  fi

  if (( size > offset )); then
    if (( state_bootstrap == 1 )); then
      # First run only records offsets to avoid importing historical turns.
      update_state_offset "$file" "$size"
      continue
    fi
    start=$((offset + 1))
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue

      line_type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null || true)
      if [[ "$line_type" == "session_meta" && -z "$cwd" ]]; then
        meta_cwd=$(printf '%s' "$line" | jq -r '.payload.cwd // empty' 2>/dev/null || true)
        if [[ -n "$meta_cwd" ]]; then
          cwd="$meta_cwd"
          update_state_kv "$file" "$cwd"
        fi
      fi

      if [[ "$line_type" == "event_msg" ]]; then
        evt_type=$(printf '%s' "$line" | jq -r '.payload.type // empty' 2>/dev/null || true)
        if [[ "$evt_type" == "task_complete" ]]; then
          turn_id=$(printf '%s' "$line" | jq -r '.payload.turn_id // empty' 2>/dev/null || true)
          if [[ -z "$cwd" ]]; then
            cwd=$(head -n 1 "$file" 2>/dev/null | jq -r '.payload.cwd // empty' 2>/dev/null || true)
            [[ -n "$cwd" ]] && update_state_kv "$file" "$cwd"
          fi
          apply_task_complete "$turn_id" "$cwd"
        fi
      fi
    done < <(tail -c +"$start" "$file" 2>/dev/null || true)
  fi

  update_state_offset "$file" "$size"
done < <(find "$CODEX_SESSIONS_DIR" -type f -name 'rollout-*.jsonl' -mmin -240 2>/dev/null | sort)

printf '%s\n' "$state_json" > "$STATE_FILE.tmp"
mv "$STATE_FILE.tmp" "$STATE_FILE"
printf '%s\n' "$cache_json" > "$CACHE_FILE.tmp"
mv "$CACHE_FILE.tmp" "$CACHE_FILE"
