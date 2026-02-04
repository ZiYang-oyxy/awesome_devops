return {
  "neovim/nvim-lspconfig",
  keys = {
    -- Disable LazyVim default LSP keymaps.
    { "<leader>cl", false },
    { "gd", false },
    { "gr", false },
    { "gI", false },
    { "gy", false },
    { "gD", false },
    { "K", false },
    { "gK", false },
    { "<c-k>", false, mode = "i" },
    { "<leader>ca", false, mode = { "n", "x" } },
    { "<leader>cc", false, mode = { "n", "x" } },
    { "<leader>cC", false },
    { "<leader>cR", false },
    { "<leader>cr", false },
    { "<leader>cA", false },
    { "]]", false },
    { "[[", false },
    { "<a-n>", false },
    { "<a-p>", false },
    { "<leader>ss", false },
    { "<leader>sS", false },
    { "gai", false },
    { "gao", false },

  },
  config = function()
    require("config.lsp").setup()
  end,
}
