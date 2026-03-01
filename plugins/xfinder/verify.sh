#!/bin/bash

set -eo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/xfinder.source"

pass_count=0
fail_count=0

pass() {
    pass_count=$((pass_count + 1))
    printf "[PASS] %s\n" "$*"
}

fail() {
    fail_count=$((fail_count + 1))
    printf "[FAIL] %s\n" "$*"
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if printf "%s" "$haystack" | grep -Fq -- "$needle"; then
        pass "$message"
    else
        fail "$message"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if printf "%s" "$haystack" | grep -Fq -- "$needle"; then
        fail "$message"
    else
        pass "$message"
    fi
}

assert_has_ansi() {
    local text="$1"
    local message="$2"
    local esc
    esc="$(printf '\033')"

    if printf "%s" "$text" | grep -q "$esc"; then
        pass "$message"
    else
        fail "$message"
    fi
}

assert_no_ansi() {
    local text="$1"
    local message="$2"
    local esc
    esc="$(printf '\033')"

    if printf "%s" "$text" | grep -q "$esc"; then
        fail "$message"
    else
        pass "$message"
    fi
}

run_interactive_smoke() {
    local target_dir="$1"
    local rc=0

    if ! TERM=xterm EDITOR=true XFINDER_COLOR=1 bash -lc \
        "source '${script_dir}/xfinder.source'; cd '${target_dir}'; grep_ed _xgrep KEY_ALPHA <<'EOF' >/tmp/xfinder_verify_grep_ed.out 2>&1
1
q
EOF"; then
        rc=1
        fail "grep_ed 可交互选择并返回"
    else
        pass "grep_ed 可交互选择并返回"
    fi

    if ! TERM=xterm EDITOR=true XFINDER_COLOR=1 bash -lc \
        "source '${script_dir}/xfinder.source'; cd '${target_dir}'; find_ed _xfind TOKENX <<'EOF' >/tmp/xfinder_verify_find_ed.out 2>&1
1
q
EOF"; then
        rc=1
        fail "find_ed 可交互选择并返回"
    else
        pass "find_ed 可交互选择并返回"
    fi

    return $rc
}

tmp_dir="$(mktemp -d)"
trap "rm -rf '${tmp_dir}'" EXIT
cd "${tmp_dir}"

mkdir -p src scripts notes .git .repo docs dir_TOKENX

cat > src/main.c <<'EOF'
int main(){ /* KEY_ALPHA */ return 0; }
EOF

cat > src/util.cc <<'EOF'
// key_alpha in c++
EOF

cat > src/tool.py <<'EOF'
print("KEY_ALPHA")
EOF

cat > scripts/run.sh <<'EOF'
#!/bin/bash
echo KEY_BETA
EOF

cat > Makefile <<'EOF'
all:
	@echo KEY_ALPHA
EOF

cat > meson.build <<'EOF'
project('k') # KEY_ALPHA
EOF

cat > CMakeLists.txt <<'EOF'
# KEY_ALPHA
EOF

cat > build.mk <<'EOF'
# KEY_ALPHA
EOF

cat > notes/plain.txt <<'EOF'
KEY_ALPHA
EOF

cat > docs/readme.md <<'EOF'
KEY_ALPHA
EOF

cat > .hidden_data <<'EOF'
KEY_ALPHA
EOF

cat > .git/ignored.txt <<'EOF'
KEY_ALPHA
EOF

cat > .repo/ignored.txt <<'EOF'
KEY_ALPHA
EOF

cat > tags <<'EOF'
KEY_ALPHA
EOF

: > file_TOKENX.log

# find family
out="$(_xfind TOKENX || true)"
assert_contains "$out" "./dir_TOKENX" "_xfind 命中目录"
assert_contains "$out" "./file_TOKENX.log" "_xfind 命中文件"

out="$(_xfindi tokenx || true)"
assert_contains "$out" "./dir_TOKENX" "_xfindi 大小写不敏感"

# grep family
out="$(_xgrep KEY_ALPHA || true)"
assert_contains "$out" ".hidden_data" "_xgrep 搜索 hidden 文件"
assert_not_contains "$out" ".git/ignored.txt" "_xgrep 排除 .git"
assert_not_contains "$out" ".repo/ignored.txt" "_xgrep 排除 .repo"
assert_not_contains "$out" "tags:" "_xgrep 排除 tags 文件"

out="$(_cgrep KEY_ALPHA || true)"
assert_contains "$out" "src/main.c" "_cgrep 命中 C 文件"
assert_not_contains "$out" "scripts/run.sh" "_cgrep 不命中 shell 文件"

out="$(_mgrep KEY_ALPHA || true)"
assert_contains "$out" "Makefile" "_mgrep 命中 Makefile"
assert_contains "$out" "meson.build" "_mgrep 命中 meson.build"

out="$(_pgrep KEY_ALPHA || true)"
assert_contains "$out" "src/tool.py" "_pgrep 命中 Python 文件"

out="$(_ogrep KEY_ALPHA || true)"
assert_contains "$out" "notes/plain.txt" "_ogrep 命中 other 类型文件"

out="$(_sgrep KEY_BETA || true)"
assert_contains "$out" "scripts/run.sh" "_sgrep 命中 shell 文件"
assert_not_contains "$out" "docs/readme.md" "_sgrep 排除 md/rst"

out="$(_xgrepi key_alpha || true)"
assert_contains "$out" "src/main.c" "_xgrepi 忽略大小写"

# color toggle priority
out="$(XFINDER_COLOR=1 _rg_search 0 x interactive KEY_ALPHA | head -n 1 || true)"
assert_has_ansi "$out" "interactive + XFINDER_COLOR=1 输出 ANSI"

out="$(XFINDER_COLOR=0 _rg_search 0 x interactive KEY_ALPHA | head -n 1 || true)"
assert_no_ansi "$out" "interactive + XFINDER_COLOR=0 无 ANSI"

# Default color mode only emits color for interactive terminals.
out="$(_rg_search 0 x interactive KEY_ALPHA | head -n 1 || true)"
assert_no_ansi "$out" "默认模式在非TTY上下文无 ANSI"

out="$(NO_COLOR=1 XFINDER_COLOR=1 _rg_search 0 x interactive KEY_ALPHA | head -n 1 || true)"
assert_has_ansi "$out" "默认开色策略下 XFINDER_COLOR=1 保持 ANSI"

out="$(XFINDER_COLOR=1 _xgrep KEY_ALPHA | head -n 1 || true)"
assert_no_ansi "$out" "_xgrep 在 XFINDER_COLOR=1 下仍无色"

out="$(printf '\033[35mabc\033[0m:12:3:text\n' | _xf_strip_ansi)"
assert_contains "$out" "abc:12:3:text" "_xf_strip_ansi 去色正确"

# palette downgrade
tput() { echo 8; }
XFINDER_COLOR=1 _xf_init_palette
out="${XF_RG_COLOR_ARGS[*]}"
assert_contains "$out" "path:fg:magenta" "低色终端降级到 ANSI 调色参数"
unset -f tput

if [ "${XFINDER_RUN_INTERACTIVE:-0}" = "1" ]; then
    run_interactive_smoke "${tmp_dir}" || true
else
    printf "[SKIP] 交互烟测默认跳过，设置 XFINDER_RUN_INTERACTIVE=1 可启用\n"
fi

printf "\nSummary: pass=%d fail=%d\n" "${pass_count}" "${fail_count}"

if [ "${fail_count}" -ne 0 ]; then
    exit 1
fi
