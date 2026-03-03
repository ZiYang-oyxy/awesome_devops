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
