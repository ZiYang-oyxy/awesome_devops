-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.filetype.add({
  filename = {
    ["go.work"] = "gowork",
    ["go.work.sum"] = "gowork",
  },
  extension = {
    gotmpl = "gotmpl",
    mdx = "markdown.mdx",
    jsx = "javascript.jsx",
    tsx = "typescript.tsx",
  },
  pattern = {
    [".*/docker%-compose%.ya?ml"] = "yaml.docker-compose",
    [".*/compose%.ya?ml"] = "yaml.docker-compose",
    [".*/%.gitlab%-ci%.ya?ml"] = "yaml.gitlab",
    [".*/helm%-values%.ya?ml"] = "yaml.helm-values",
    [".*/values%.ya?ml"] = "yaml.helm-values",
  },
})

-- Reuse existing parsers for custom dotted filetypes.
if vim.treesitter and vim.treesitter.language and vim.treesitter.language.register then
  vim.treesitter.language.register("yaml", "yaml.docker-compose")
  vim.treesitter.language.register("yaml", "yaml.gitlab")
  vim.treesitter.language.register("yaml", "yaml.helm-values")
  vim.treesitter.language.register("gotmpl", "gotmpl")
  vim.treesitter.language.register("markdown", "markdown.mdx")
  vim.treesitter.language.register("javascript", "javascript.jsx")
  vim.treesitter.language.register("tsx", "typescript.tsx")
end
