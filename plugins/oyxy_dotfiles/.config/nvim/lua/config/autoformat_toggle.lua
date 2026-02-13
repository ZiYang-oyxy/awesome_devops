local M = {}

local function is_enabled_from_global()
  return vim.g.autoformat == nil or vim.g.autoformat
end

function M.is_enabled()
  return is_enabled_from_global()
end

function M.status_text()
  return M.is_enabled() and "FMT:ON" or "FMT:OFF"
end

function M.refresh_lualine()
  local ok, lualine = pcall(require, "lualine")
  if ok and lualine and type(lualine.refresh) == "function" then
    lualine.refresh({ place = { "statusline" } })
  end
end

function M.set_enabled(enabled)
  vim.g.autoformat = enabled

  -- Clear all loaded buffer-local overrides so global state stays authoritative.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.b[bufnr].autoformat = nil
    end
  end

  M.refresh_lualine()
  return enabled
end

function M.toggle()
  return M.set_enabled(not M.is_enabled())
end

return M
