return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      enabled = false,
    },
  },
  {
    "ZiYang-oyxy/markdown-preview.nvim",
    build = "cd app && npx --yes yarn install",
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
