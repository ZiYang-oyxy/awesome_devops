---@diagnostic disable: undefined-global

local M = {}

M.opts = {
  picker = {
    win = {
      input = {
        keys = {
          ["<F9>"] = { "close", mode = { "n", "i" } },
          ["<C-p>"] = { "close", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["<F9>"] = "close",
          ["<C-p>"] = "close",
        },
      },
    },
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

  local function toggle_symbols_picker()
    if snacks.picker and snacks.picker.get then
      local active = snacks.picker.get({ tab = true })
      if #active > 0 then
        active[1]:close()
        return
      end
    end
    if snacks.picker and snacks.picker.lsp_symbols then
      snacks.picker.lsp_symbols()
      return
    end
    LazyVim.pick("lsp_symbols")()
  end

  vim.keymap.set("n", "<F9>", toggle_symbols_picker, { desc = "Toggle Symbols" })
  vim.keymap.set("n", "<leader><F8>", function()
    snacks.picker.explorer({ cwd = get_root() })
  end, { desc = "Snacks explorer (root)" })
  vim.keymap.set("n", "<F8>", function()
    snacks.picker.explorer({ cwd = get_cwd() })
  end, { desc = "Snacks explorer (cwd)" })
end

return M
