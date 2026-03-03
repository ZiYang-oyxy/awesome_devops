#!/usr/bin/env bash
set -euo pipefail

# Args: <pane_pid> <pane_width> <pane_path> <pane_cmd>
pid="${1:-}"
width="${2:-80}"
pane_path="${3:-$PWD}"
pane_cmd="${4:-}"

# Best-effort: inherit venv/conda from the pane's process env
if [[ -n "$pid" ]]; then
  ps_line=$(ps e -p "$pid" -o command= 2>/dev/null || true)
  if [[ -n "$ps_line" ]]; then
    venv=$(printf '%s' "$ps_line" | sed -n 's/.*[[:space:]]VIRTUAL_ENV=\([^[:space:]]*\).*/\1/p' | tail -n1)
    conda_env=$(printf '%s' "$ps_line" | sed -n 's/.*[[:space:]]CONDA_DEFAULT_ENV=\([^[:space:]]*\).*/\1/p' | tail -n1)
    conda_prefix=$(printf '%s' "$ps_line" | sed -n 's/.*[[:space:]]CONDA_PREFIX=\([^[:space:]]*\).*/\1/p' | tail -n1)
    [[ -n "$venv" ]] && export VIRTUAL_ENV="$venv"
    [[ -n "$conda_env" ]] && export CONDA_DEFAULT_ENV="$conda_env"
    [[ -n "$conda_prefix" ]] && export CONDA_PREFIX="$conda_prefix"
  fi
fi

strip_wrappers() {
  # strip bash \[\] and zsh %{ %}
  sed -E 's/\\\[|\\\]//g; s/%\{|%\}//g'
}

ansi_to_tmux_styles() {
  # Map common ANSI SGR sequences into tmux inline styles.
  # Keep pane background untouched: only foreground + bold are mapped.
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

run_starship() {
  local cfg
  cfg="${STARSHIP_TMUX_CONFIG:-$HOME/.config/starship-tmux.toml}"
  STARSHIP_LOG=error STARSHIP_CONFIG="$cfg" \
    starship prompt --terminal-width "$width" | strip_wrappers | ansi_to_tmux_styles | tr -d '\n'
}

fallback() {
  # <cmd> — <last dir>
  local last_dir
  last_dir="${pane_path##*/}"
  printf '%s — %s' "$pane_cmd" "$last_dir"
}

if command -v starship >/dev/null 2>&1; then
  (cd "$pane_path" && run_starship) || fallback
else
  fallback
fi
