return {
  {
    dir = "/Volumes/code/vim-dirdiff",
    name = "vim-dirdiff-local",
    main = "dirdiff",
    lazy = false,
    dependencies = {
      { "folke/snacks.nvim", optional = true },
    },
    opts = {
      use_snacks = false,
      list_mode = "quickfix",
      confirm_ops = true,
    },
    keys = {
      { "<leader>dd", "<cmd>DirDiff<cr>", desc = "DirDiff (prompt)" },
      { "<leader>dn", "<cmd>DirDiffNext<cr>", desc = "DirDiff next" },
      { "<leader>dp", "<cmd>DirDiffPrev<cr>", desc = "DirDiff prev" },
    },
  },
}
