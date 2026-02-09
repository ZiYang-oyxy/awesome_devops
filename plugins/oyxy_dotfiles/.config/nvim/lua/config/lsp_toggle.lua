local M = {
  enabled = true,
  servers = {},
  initialized = false,
  native_enable = nil,
}

local function ensure_lsp_loaded()
  local ok, lazy = pcall(require, "lazy")
  if not ok then
    return
  end

  lazy.load({ plugins = { "nvim-lspconfig", "mason-lspconfig.nvim" } })
end

local function configured_servers()
  local names = {}
  local seen = {}

  for name in pairs(M.servers) do
    if name ~= "*" and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end

  if vim.lsp and vim.lsp.config and vim.lsp.config._configs then
    for name in pairs(vim.lsp.config._configs) do
      if name ~= "*" and not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end

  table.sort(names)
  return names
end

local function clear_all_buffer_diagnostics()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.diagnostic.reset(nil, bufnr)
    end
  end
end

local function enable_all_configured_servers()
  local names = configured_servers()
  if #names > 0 and type(vim.lsp.enable) == "function" then
    vim.lsp.enable(names, true)
  end
end

function M.setup()
  if M.initialized then
    return
  end

  M.initialized = true

  if type(vim.lsp.enable) == "function" and not M.native_enable then
    M.native_enable = vim.lsp.enable
  end
end

function M.configure_server(server, opts)
  M.servers[server] = true
  vim.lsp.config(server, opts)

  if M.enabled and type(vim.lsp.enable) == "function" then
    vim.lsp.enable(server, true)
  end
end

function M.is_enabled()
  return M.enabled
end

function M.enable(silent)
  M.setup()
  M.enabled = true
  ensure_lsp_loaded()

  enable_all_configured_servers()

  vim.defer_fn(function()
    if M.enabled then
      enable_all_configured_servers()
    end
  end, 100)

  if not silent then
    vim.notify("LSP: ON")
  end

  return true
end

function M.disable(silent)
  M.setup()
  M.enabled = false

  local names = configured_servers()
  if #names > 0 and M.native_enable then
    M.native_enable(names, false)
  elseif #names > 0 and type(vim.lsp.enable) == "function" then
    vim.lsp.enable(names, false)
  end

  clear_all_buffer_diagnostics()

  if not silent then
    vim.notify("LSP: OFF")
  end

  return false
end

function M.toggle()
  M.setup()
  if M.enabled then
    return M.disable()
  end

  return M.enable()
end

return M
