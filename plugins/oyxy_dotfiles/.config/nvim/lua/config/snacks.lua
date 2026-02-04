---@diagnostic disable: undefined-global

local M = {}

M.opts = {
  picker = {
    sources = {
      explorer = {
        layout = { layout = { position = "right" } },
        win = {
          list = {
            keys = {
              ["o"] = "confirm",
            },
          },
        },
        on_show = function(picker)
          picker.title = vim.fn.fnamemodify(picker:cwd(), ":p")
          picker:update_titles()
        end,
      },
    },
  },
}

local function get_root()
  if _G.LazyVim and LazyVim.root then
    return LazyVim.root()
  end
  return vim.fn.getcwd()
end

function M.setup(opts)
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    return
  end

  if snacks.setup then
    snacks.setup(opts or {})
  end

  vim.keymap.set("n", "<F8>", function()
    snacks.picker.explorer({ cwd = get_root() })
  end, { desc = "Snacks explorer (root)" })
end

return M
