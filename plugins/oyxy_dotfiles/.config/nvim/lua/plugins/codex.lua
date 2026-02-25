return {
  {
    "ZiYang-oyxy/codex.nvim",
    config = function()
      require("codex").setup({
        args = { "--full-auto" },
      })
    end,
  },
}
