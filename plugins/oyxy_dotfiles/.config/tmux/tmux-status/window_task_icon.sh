#!/usr/bin/env bash
set -euo pipefail

window_id="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/status_engine.sh"

[[ -z "$window_id" ]] && exit 0

count=$("$ENGINE" query count --scope window --id "$window_id" --kind bell 2>/dev/null || echo 0)
[[ "$count" =~ ^[0-9]+$ ]] || count=0

if ((count <= 0)); then
    exit 0
fi
printf '%s󰅖🔔' "$count"
