#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
UPDATE_SCRIPT="$REPO_ROOT/update-devops-and-dotfiles.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run_git() {
  git -c user.name="Test User" -c user.email="test@example.com" "$@"
}

create_dotfiles_repo() {
  local repo="$1"
  mkdir -p "$repo/ai/scripts"
  cat >"$repo/ai/scripts/install-codex-config.sh" <<'EOS'
#!/bin/bash
set -euo pipefail
codex_home=""
while [ "$#" -gt 0 ]; do
  case "$1" in
  --codex-home)
    codex_home="$2"
    shift 2
    ;;
  *)
    shift
    ;;
  esac
done
[ -n "$codex_home" ] || exit 2
mkdir -p "$codex_home"
printf 'installed\n' >"$codex_home/update-helper-installed"
EOS
  chmod +x "$repo/ai/scripts/install-codex-config.sh"
  run_git -C "$repo" init -q
  run_git -C "$repo" add .
  run_git -C "$repo" commit -qm "initial dotfiles"
}

test_migrates_embedded_dotfiles_and_runs_installer() {
  local tmp main_src main_origin main_work dot_src dot_origin codex_home
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/update-devops-test.XXXXXX")"
  main_src="$tmp/main-src"
  main_origin="$tmp/main-origin.git"
  main_work="$tmp/main-work"
  dot_src="$tmp/dot-src"
  dot_origin="$tmp/dot-origin.git"
  codex_home="$tmp/codex-home"

  mkdir -p "$main_src/plugins/oyxy_dotfiles"
  printf 'legacy embedded content\n' >"$main_src/plugins/oyxy_dotfiles/legacy.txt"
  run_git -C "$main_src" init -q
  run_git -C "$main_src" add .
  run_git -C "$main_src" commit -qm "initial main"
  run_git clone --bare -q "$main_src" "$main_origin"
  run_git clone -q "$main_origin" "$main_work"

  mkdir -p "$dot_src"
  create_dotfiles_repo "$dot_src"
  run_git clone --bare -q "$dot_src" "$dot_origin"

  "$UPDATE_SCRIPT" \
    --repo-root "$main_work" \
    --dotfiles-url "$dot_origin" \
    --codex-home "$codex_home" \
    --no-verify >/tmp/update-devops-and-dotfiles.out

  [ -d "$main_work/plugins/oyxy_dotfiles/.git" ] ||
    fail "expected independent dotfiles clone"
  [ -f "$codex_home/update-helper-installed" ] ||
    fail "expected installer to run"
  find "$main_work/plugins" -maxdepth 1 -type d -name 'oyxy_dotfiles.pre-independent-*' | grep -q . ||
    fail "expected embedded dotfiles backup"
}

test_migrates_embedded_dotfiles_and_runs_installer

echo "OK update-devops-and-dotfiles tests"
