return {
  {
    dir = "~/code/markdown-preview.nvim",
    name = "markdown-preview.nvim",
    keys = {
      { "<leader>cp", false },
      {
        "<leader>md",
        ft = "markdown",
        "<cmd>MarkdownPreviewToggle<cr>",
        desc = "Markdown Preview",
      },
    },
  },
}
