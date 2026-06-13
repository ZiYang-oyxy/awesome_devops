#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$SCRIPT_DIR"
DOTFILES_URL="${OYXY_DOTFILES_URL:-https://github.com/ZiYang-oyxy/oyxy_dotfiles.git}"
DOTFILES_DIR=""
CODEX_HOME_ARG=""
VERIFY=1
STAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'EOF'
Usage: update-devops-and-dotfiles.sh [options]

Updates awesome_devops and its independent oyxy_dotfiles checkout, then installs
the Codex config layout.

Options:
  --repo-root PATH     awesome_devops checkout to update
  --dotfiles-url URL   git URL for oyxy_dotfiles
  --dotfiles-dir PATH  target dotfiles checkout path
  --codex-home PATH    Codex home passed to the dotfiles installer
  --no-verify          skip installer verification
  -h, --help           show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --repo-root)
    [ "$#" -ge 2 ] || {
      echo "--repo-root requires a path" >&2
      exit 2
    }
    REPO_ROOT="$2"
    shift 2
    ;;
  --dotfiles-url)
    [ "$#" -ge 2 ] || {
      echo "--dotfiles-url requires a URL" >&2
      exit 2
    }
    DOTFILES_URL="$2"
    shift 2
    ;;
  --dotfiles-dir)
    [ "$#" -ge 2 ] || {
      echo "--dotfiles-dir requires a path" >&2
      exit 2
    }
    DOTFILES_DIR="$2"
    shift 2
    ;;
  --codex-home)
    [ "$#" -ge 2 ] || {
      echo "--codex-home requires a path" >&2
      exit 2
    }
    CODEX_HOME_ARG="$2"
    shift 2
    ;;
  --no-verify)
    VERIFY=0
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "required command missing: $1" >&2
    exit 1
  }
}

abs_dir() {
  local path="$1"
  mkdir -p "$path"
  cd "$path" && pwd -P
}

abs_path_with_parent() {
  local path="$1"
  local parent
  local name
  parent="$(dirname "$path")"
  name="$(basename "$path")"
  mkdir -p "$parent"
  parent="$(cd "$parent" && pwd -P)"
  printf '%s/%s' "$parent" "$name"
}

next_backup_path() {
  local base="$1"
  local candidate="${base}.pre-independent-$STAMP"
  local index=1
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="${base}.pre-independent-$STAMP-$index"
    index=$((index + 1))
  done
  printf '%s' "$candidate"
}

is_git_checkout_root() {
  local dir="$1"
  local top
  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [ "$(cd "$top" && pwd -P)" = "$(cd "$dir" && pwd -P)" ]
}

require_command git

REPO_ROOT="$(abs_dir "$REPO_ROOT")"
if [ -z "$DOTFILES_DIR" ]; then
  DOTFILES_DIR="$REPO_ROOT/plugins/oyxy_dotfiles"
else
  DOTFILES_DIR="$(abs_path_with_parent "$DOTFILES_DIR")"
fi
DOTFILES_PARENT="$(dirname "$DOTFILES_DIR")"

if ! is_git_checkout_root "$REPO_ROOT"; then
  echo "repo root is not a git checkout: $REPO_ROOT" >&2
  exit 1
fi

echo "Updating awesome_devops: $REPO_ROOT"
git -C "$REPO_ROOT" pull --ff-only

mkdir -p "$DOTFILES_PARENT"
if [ -e "$DOTFILES_DIR" ] || [ -L "$DOTFILES_DIR" ]; then
  if is_git_checkout_root "$DOTFILES_DIR"; then
    echo "Updating oyxy_dotfiles: $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only
  else
    backup="$(next_backup_path "$DOTFILES_DIR")"
    echo "Moving embedded oyxy_dotfiles to: $backup"
    mv "$DOTFILES_DIR" "$backup"
    echo "Cloning oyxy_dotfiles: $DOTFILES_URL"
    git clone "$DOTFILES_URL" "$DOTFILES_DIR"
  fi
else
  echo "Cloning oyxy_dotfiles: $DOTFILES_URL"
  git clone "$DOTFILES_URL" "$DOTFILES_DIR"
fi

INSTALLER="$DOTFILES_DIR/ai/scripts/install-codex-config.sh"
if [ ! -x "$INSTALLER" ]; then
  echo "dotfiles installer missing or not executable: $INSTALLER" >&2
  exit 1
fi

install_args=(--dotfiles-root "$DOTFILES_DIR")
if [ -n "$CODEX_HOME_ARG" ]; then
  install_args+=(--codex-home "$CODEX_HOME_ARG")
fi
if [ "$VERIFY" -eq 0 ]; then
  install_args+=(--no-verify)
fi

"$INSTALLER" "${install_args[@]}"
echo "Updated awesome_devops and oyxy_dotfiles"
