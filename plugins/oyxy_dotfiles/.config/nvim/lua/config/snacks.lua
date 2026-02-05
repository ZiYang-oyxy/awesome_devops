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
          picker.title = M.format_cwd(picker:cwd())
          picker:update_titles()
        end,
      },
    },
  },
}

function M.format_cwd(cwd)
  return vim.fn.fnamemodify(cwd, ":p")
end

local function get_cwd()
  return vim.fn.getcwd()
end

local function get_root()
  local buf = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(buf)
  local buf_dir = buf_path ~= "" and vim.fs.dirname(buf_path) or nil
  if buf_dir then
    local marker = vim.fs.find({ ".git", "lua" }, { path = buf_dir, upward = true })[1]
    if marker then
      return vim.fs.dirname(marker)
    end
  end

  local ok, lazyvim = pcall(require, "lazyvim.util")
  if ok and lazyvim.root then
    return lazyvim.root.get({ normalize = true, buf = buf })
  end
  return get_cwd()
end

function M.setup(opts)
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    return
  end

  if snacks.setup then
    snacks.setup(opts or {})
  end

  vim.keymap.set("n", "<leader><F8>", function()
    snacks.picker.explorer({ cwd = get_root() })
  end, { desc = "Snacks explorer (root)" })
  vim.keymap.set("n", "<F8>", function()
    snacks.picker.explorer({ cwd = get_cwd() })
  end, { desc = "Snacks explorer (cwd)" })
end

return M
