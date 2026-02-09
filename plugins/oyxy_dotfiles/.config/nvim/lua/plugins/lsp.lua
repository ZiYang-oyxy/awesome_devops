---@diagnostic disable: undefined-global
local function snacks_only(snacks_action)
  return function()
    local ok, snacks = pcall(require, "snacks")
    if ok and snacks and snacks.picker then
      snacks_action(snacks.picker)
      return
    end

    vim.notify("Snacks picker is not available", vim.log.levels.WARN)
  end
end

local function ivy_opts(opts)
  return vim.tbl_deep_extend("force", {
    layout = { preset = "ivy" },
  }, opts or {})
end

return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    local lsp_toggle = require("config.lsp_toggle")
    lsp_toggle.setup()

    opts.servers = opts.servers or {}
    opts.servers["*"] = opts.servers["*"] or {}
    opts.servers["*"].keys = opts.servers["*"].keys or {}

    vim.list_extend(opts.servers["*"].keys, {
      {
        "<C-2>s",
        snacks_only(function(picker)
          picker.lsp_workspace_symbols(ivy_opts({
            search = vim.fn.expand("<cword>"),
          }))
        end),
        desc = "LSP Workspace Symbols",
      },
      {
        "<C-2>g",
        snacks_only(function(picker)
          picker.lsp_definitions(ivy_opts())
        end),
        desc = "LSP Definition",
      },
      {
        "<C-2>c",
        snacks_only(function(picker)
          picker.lsp_incoming_calls(ivy_opts())
        end),
        desc = "LSP Incoming Calls",
      },
      {
        "<C-2>t",
        snacks_only(function(picker)
          picker.lsp_references(ivy_opts())
        end),
        desc = "LSP References",
      },
      {
        "<C-2>d",
        snacks_only(function(picker)
          picker.lsp_outgoing_calls(ivy_opts())
        end),
        desc = "LSP Outgoing Calls",
      },
      {
        "<C-2>e",
        snacks_only(function(picker)
          picker.grep(ivy_opts())
        end),
        desc = "Live Grep",
      },
      {
        "<C-2>f",
        snacks_only(function(picker)
          picker.files(ivy_opts())
        end),
        desc = "Find Files",
      },
      {
        "<C-2>i",
        snacks_only(function(picker)
          picker.grep(ivy_opts({
            search = vim.fn.expand("<cfile>"),
            regex = false,
          }))
        end),
        desc = "Grep Current File Name",
      },
    })

    opts.setup = opts.setup or {}
    local base_setup = opts.setup["*"]
    opts.setup["*"] = function(server, server_opts)
      if type(base_setup) == "function" and base_setup(server, server_opts) then
        return true
      end

      lsp_toggle.configure_server(server, server_opts)
      return true
    end

    return opts
  end,
}
