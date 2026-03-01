#!/usr/bin/env bash
set -euo pipefail

scope="${1:-}"
target_id="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/status_engine.sh"

[[ -z "$scope" || -z "$target_id" ]] && exit 0
[[ "$scope" != "session" && "$scope" != "window" ]] && exit 0

count=$("$ENGINE" query count --scope "$scope" --id "$target_id" --kind robot 2>/dev/null || echo 0)
[[ "$count" =~ ^[0-9]+$ ]] || count=0
((count > 0)) || exit 0

if [[ "$scope" == "window" ]]; then
    printf ' %s󰅖🤖' "$count"
else
    printf ' %s󰅖🤖' "$count"
fi
