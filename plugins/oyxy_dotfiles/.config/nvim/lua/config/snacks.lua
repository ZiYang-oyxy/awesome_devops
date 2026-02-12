---@diagnostic disable: undefined-global

local M = {}

local function patch_explorer_watch(snacks)
  if vim.fn.has("mac") ~= 1 then
    return
  end
  local ok_watch, watch = pcall(require, "snacks.explorer.watch")
  if not ok_watch or watch._oyxy_compact_watch then
    return
  end

  local Tree = require("snacks.explorer.tree")
  local Git = require("snacks.explorer.git")
  watch._oyxy_compact_watch = true

  watch.watch = function()
    local used = {} ---@type table<string, boolean>
    local pickers = snacks.picker.get({ source = "explorer", tab = false })
    local cwds = {} ---@type table<string, boolean>
    for _, picker in ipairs(pickers) do
      cwds[picker:cwd()] = true
    end

    for cwd in pairs(cwds) do
      used[cwd] = true
      watch.start(cwd, function(file)
        Tree:refresh(file or cwd)
        watch.refresh()
      end)

      local root = snacks.git.get_root(cwd)
      if root then
        local git_dir = root .. "/.git"
        used[git_dir] = true
        watch.start(git_dir, function(file)
          if vim.fs.basename(file) == "index" then
            Git.refresh(root)
            watch.refresh()
          end
        end)
      end
    end

    for path in pairs(watch._watches) do
      if not used[path] then
        watch.stop(path)
      end
    end
  end
end

local function explorer_target_dir(picker, item)
  local path = item and item.file or picker:dir()
  if not path or path == "" then
    return picker:dir()
  end
  if vim.fn.isdirectory(path) == 1 then
    return path
  end
  return vim.fs.dirname(path)
end

local function explorer_open_recursive(picker, item)
  local Tree = require("snacks.explorer.tree")
  local Actions = require("snacks.explorer.actions")
  local root = explorer_target_dir(picker, item)
  local node = Tree:find(root)

  Tree:walk(node, function(n)
    if n.dir then
      n.open = true
      Tree:expand(n)
    end
  end, { all = true })

  Actions.update(picker, { target = root, refresh = true })
end

local function explorer_close_recursive(picker, item)
  local Tree = require("snacks.explorer.tree")
  local Actions = require("snacks.explorer.actions")
  local root = explorer_target_dir(picker, item)
  local node = Tree:find(root)

  Tree:walk(node, function(n)
    if n.dir then
      n.open = false
      n.expanded = false
    end
  end, { all = true })

  Actions.update(picker, { target = root, refresh = true })
end

local function explorer_symbol_desc(meaning)
  return meaning
end

local function explorer_symbol_key(icon, fallback, alt)
  local key = tostring(icon or fallback or alt or "?")
  key = vim.trim(key)
  if key == "" then
    key = fallback or alt or "?"
  end
  if key == "?" then
    key = alt or ""
  end
  return key
end

local function explorer_legend_entries(picker)
  local icons = picker.opts.icons or {}
  local git = icons.git or {}
  local diagnostics = icons.diagnostics or {}

  return {
    {
      explorer_symbol_key(git.staged, "●"),
      explorer_symbol_desc("Git staged"),
    },
    {
      explorer_symbol_key(git.added, ""),
      explorer_symbol_desc("Git added"),
    },
    {
      explorer_symbol_key(git.modified, "○"),
      explorer_symbol_desc("Git modified"),
    },
    {
      explorer_symbol_key(git.deleted, ""),
      explorer_symbol_desc("Git deleted"),
    },
    {
      explorer_symbol_key(git.renamed, ""),
      explorer_symbol_desc("Git renamed"),
    },
    {
      explorer_symbol_key(git.unmerged, ""),
      explorer_symbol_desc("Git unmerged/conflict"),
    },
    {
      explorer_symbol_key(git.untracked, "?", ""),
      explorer_symbol_desc("Git untracked"),
    },
    {
      explorer_symbol_key(git.ignored, ""),
      explorer_symbol_desc("Git ignored"),
    },
    {
      explorer_symbol_key(git.copied, "C"),
      explorer_symbol_desc("Git copied (fallback)"),
    },
    {
      explorer_symbol_key(diagnostics.Error, ""),
      explorer_symbol_desc("Diagnostics error"),
    },
    {
      explorer_symbol_key(diagnostics.Warn, ""),
      explorer_symbol_desc("Diagnostics warn"),
    },
    {
      explorer_symbol_key(diagnostics.Info, ""),
      explorer_symbol_desc("Diagnostics info"),
    },
    {
      explorer_symbol_key(diagnostics.Hint, ""),
      explorer_symbol_desc("Diagnostics hint"),
    },
  }
end

local function explorer_legend_noop() end

local function explorer_register_legend_keymaps(picker)
  local list_win = picker and picker.list and picker.list.win
  if not list_win or not list_win.buf or not vim.api.nvim_buf_is_valid(list_win.buf) then
    return
  end
  local buf = list_win.buf
  if vim.b[buf].oyxy_explorer_legend_mapped then
    return
  end

  for _, legend in ipairs(explorer_legend_entries(picker)) do
    vim.keymap.set("n", legend[1], explorer_legend_noop, {
      buffer = buf,
      nowait = true,
      silent = true,
      desc = legend[2],
    })
  end
  vim.b[buf].oyxy_explorer_legend_mapped = true
end

local function explorer_toggle_help(picker)
  if not (picker and picker.list and picker.list.win) then
    return
  end
  explorer_register_legend_keymaps(picker)
  picker.list.win:toggle_help()
end

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
        layout = { layout = { position = "right" }, cycle = false },
        actions = {
          explorer_open_recursive = explorer_open_recursive,
          explorer_close_recursive = explorer_close_recursive,
          explorer_toggle_help = {
            action = explorer_toggle_help,
            desc = "Toggle help + explorer symbol legend",
          },
        },
        win = {
          list = {
            keys = {
              ["<BS>"] = "explorer_close_recursive",
              ["?"] = "explorer_toggle_help",
              ["u"] = "explorer_up",
              ["h"] = false,
              ["l"] = false,
              ["o"] = "confirm",
              ["O"] = "explorer_open_recursive",
            },
          },
        },
        on_show = function(picker)
          explorer_register_legend_keymaps(picker)
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
  patch_explorer_watch(snacks)

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
