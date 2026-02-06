-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set

local function force_map(mode, lhs, rhs, opts)
  pcall(vim.keymap.del, mode, lhs)
  keymap(mode, lhs, rhs, opts)
end

local function ensure_kaleidosearch_loaded()
  pcall(function()
    require("lazy").load({ plugins = { "kaleidosearch.nvim" } })
  end)
end

local function with_kaleidosearch(callback)
  return function()
    ensure_kaleidosearch_loaded()
    callback()
  end
end

keymap("n", "<leader>q", "<cmd>qa!<cr>", { desc = "Quit all" })
keymap("n", "<leader>a", "A", { desc = "Append end of line" })
keymap("x", "p", '"_dP') -- 使用黑洞寄存器，避免覆盖clipboard
keymap({ "n", "v" }, "d", '"_d') -- 使用黑洞寄存器clipboard
keymap("n", "q", "<Nop>", { desc = "Disable macro recording" })
keymap("n", "Q", "<Nop>", { desc = "Disable Ex mode" })
keymap("n", "-", "^")
keymap("n", "=", "$")
keymap("v", "-", "^")
keymap("v", "=", "$")
keymap({ "n", "v" }, "$", "%", { desc = "Jump to match" })
force_map(
  { "n", "v" },
  "@",
  with_kaleidosearch(function()
    require("config.kaleidosearch").jump_prev_current_match()
  end),
  { desc = "KaleidoSearch: Jump to previous match (cycle)", silent = true }
)
force_map(
  { "n", "v" },
  "#",
  with_kaleidosearch(function()
    require("config.kaleidosearch").jump_next_current_match()
  end),
  { desc = "KaleidoSearch: Jump to next match (cycle)", silent = true }
)
keymap("n", "<leader>ss", "<cmd>source $MYVIMRC<cr>", { desc = "Reload config" })
keymap("n", "<leader>ee", "<cmd>edit ~/Documents/byte/Notes/note.md<cr>", { desc = "Edit note.md" })
keymap("n", "<F9>", function()
  require("trouble").toggle({
    mode = "lsp",
    warn_no_results = false,
    open_no_results = true,
    win = {
      position = "bottom",
    },
  })
end, { desc = "Trouble LSP (toggle)" })

force_map(
  "n",
  "<leader><cr>",
  with_kaleidosearch(function()
    vim.cmd("KaleidosearchClear")
  end),
  { desc = "KaleidoSearch: Clear all matches", silent = true }
)

force_map(
  "n",
  "<leader>`",
  with_kaleidosearch(function()
    require("config.kaleidosearch").show_matching_rules()
  end),
  { desc = "KaleidoSearch: List groups (Enter to jump)", silent = true }
)

force_map(
  "n",
  "!",
  with_kaleidosearch(function()
    require("config.kaleidosearch").mark_word_or_selection()
  end),
  { desc = "KaleidoSearch: Toggle word or selection", silent = true }
)

force_map(
  "x",
  "!",
  with_kaleidosearch(function()
    require("config.kaleidosearch").mark_visual_selection()
  end),
  { desc = "KaleidoSearch: Toggle visual selection", silent = true }
)
