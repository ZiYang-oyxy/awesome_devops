#!/usr/bin/env bash
set -euo pipefail

# Determine theme color from tmux user option with fallback.
theme=$(tmux show -gqv @theme_color 2>/dev/null || true)
if [[ -z "$theme" ]]; then
  theme="#9A2600"
fi

# Cache as a user option and apply to border style
tmux set -g @theme_color "$theme"

exit 0
