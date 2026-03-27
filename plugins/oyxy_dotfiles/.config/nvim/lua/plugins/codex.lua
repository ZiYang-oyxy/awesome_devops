return {
  {
    "ZiYang-oyxy/codex.nvim",
    config = function()
      local args = {
        "--dangerously-bypass-approvals-and-sandbox",
      }

      local cwd = vim.loop.cwd() or vim.fn.getcwd()
      local git_root = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
      local project_root = cwd
      if vim.v.shell_error == 0 and git_root and git_root[1] and git_root[1] ~= "" then
        project_root = git_root[1]
      end
      local escaped_project_root = project_root:gsub("\\", "\\\\"):gsub('"', '\\"')
      table.insert(args, "-c")
      table.insert(args, string.format('projects={"%s"={trust_level="trusted"}}', escaped_project_root))

      require("codex").setup({
        args = args,
      })
    end,
  },
}
