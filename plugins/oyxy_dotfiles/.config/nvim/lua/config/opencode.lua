---@diagnostic disable: undefined-global
local M = {}

function M.setup()
  local pid = vim.loop.os_getpid()
  local base_port = 23000
  local port_range = 30000
  local port = base_port + (pid % port_range)

  vim.g.opencode_opts = {
    port = port,
    provider = {
      -- Ensure we use the integrated snacks provider by default.
      enabled = "snacks",
    },
  }

  -- Required for `opts.events.reload`.
  vim.o.autoread = true

  -- Recommended/example keymaps.
  vim.keymap.set({ "n", "x" }, "<C-a>", function()
    require("opencode").ask("@this: ", { submit = true })
  end, { desc = "Ask opencode..." })
  vim.keymap.set({ "n", "x" }, "<C-x>", function()
    require("opencode").select()
  end, { desc = "Execute opencode action..." })
  vim.keymap.set({ "n", "t" }, "<C-.>", function()
    require("opencode").toggle()
  end, { desc = "Toggle opencode" })
  vim.keymap.set({ "n", "x" }, "go", function()
    return require("opencode").operator("@this ")
  end, { desc = "Add range to opencode", expr = true })
  vim.keymap.set("n", "goo", function()
    return require("opencode").operator("@this ") .. "_"
  end, { desc = "Add line to opencode", expr = true })
  vim.keymap.set("n", "<S-C-u>", function()
    require("opencode").command("session.half.page.up")
  end, { desc = "Scroll opencode up" })
  vim.keymap.set("n", "<S-C-d>", function()
    require("opencode").command("session.half.page.down")
  end, { desc = "Scroll opencode down" })

  -- If you keep the <C-a>/<C-x> bindings above, you may want these.
  vim.keymap.set("n", "+", "<C-a>", { desc = "Increment under cursor", noremap = true })
  vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement under cursor", noremap = true })
end

return M
