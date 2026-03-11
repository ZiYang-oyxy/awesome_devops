return {
  {
    "ZiYang-oyxy/codex.nvim",
    config = function()
      local function collect_mcp_names()
        local names = {}
        local seen = {}
        local home = vim.env.HOME
        if not home or home == "" then
          return names
        end

        local cfg = home .. "/.codex/config.toml"
        local file = io.open(cfg, "r")
        if not file then
          return names
        end

        for line in file:lines() do
          local name = line:match("^%[mcp_servers%.([^%]]+)%]")
          if name then
            name = name:gsub('"', "")
            if name ~= "" and not seen[name] then
              seen[name] = true
              table.insert(names, name)
            end
          end
        end
        file:close()
        table.sort(names)
        return names
      end

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

      for _, name in ipairs(collect_mcp_names()) do
        table.insert(args, "-c")
        table.insert(args, "mcp_servers." .. name .. ".enabled=false")
      end

      require("codex").setup({
        args = args,
      })
    end,
  },
}
