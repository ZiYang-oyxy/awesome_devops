return {
  {
    "ZiYang-oyxy/codex.nvim",
    config = function()
      require("codex").setup({
        cmd = {
          "bash",
          "-lc",
          [[
cwd="$PWD"
git_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"

escape_toml_path() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

cmd=(codex --dangerously-bypass-approvals-and-sandbox)
projects_override="projects={\"$(escape_toml_path "$cwd")\"={trust_level=\"trusted\"}"

if [ -n "$git_root" ] && [ "$git_root" != "$cwd" ]; then
  projects_override+=",\"$(escape_toml_path "$git_root")\"={trust_level=\"trusted\"}"
fi

projects_override+="}"
cmd+=(-c "$projects_override")

exec "${cmd[@]}"
          ]],
        },
      })
    end,
  },
}
