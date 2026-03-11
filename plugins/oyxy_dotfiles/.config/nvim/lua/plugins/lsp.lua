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

local function sanitize_search_text(text)
  if not text then
    return nil
  end
  local sanitized = text:gsub("\r", " "):gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if sanitized == "" then
    return nil
  end
  return sanitized
end

local function get_visual_selection_text_by_yank()
  local reg_name = "z"
  local reg_value = vim.fn.getreg(reg_name)
  local reg_type = vim.fn.getregtype(reg_name)
  vim.cmd(string.format('silent normal! "%sy', reg_name))
  local text = vim.fn.getreg(reg_name)
  vim.fn.setreg(reg_name, reg_value, reg_type)
  return sanitize_search_text(text)
end

return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    local lsp_toggle = require("config.lsp_toggle")
    lsp_toggle.setup()

    opts.diagnostics = opts.diagnostics or {}
    opts.diagnostics.virtual_text = false
    opts.inlay_hints = opts.inlay_hints or {}
    opts.inlay_hints.enabled = false

    opts.servers = opts.servers or {}
    opts.servers["*"] = opts.servers["*"] or {}
    opts.servers["*"].keys = opts.servers["*"].keys or {}

    vim.list_extend(opts.servers["*"].keys, {
      {
        "<leader>cs",
        snacks_only(function(picker)
          local mode = vim.api.nvim_get_mode().mode
          local search = sanitize_search_text(vim.fn.expand("<cword>"))
          if mode == "v" or mode == "V" or mode == "\22" then
            search = get_visual_selection_text_by_yank()
          end
          picker.grep(ivy_opts({
            search = search,
            regex = false,
          }))
        end),
        mode = { "n", "x" },
        desc = "Grep (cword/selection)",
      },
      {
        "<leader>cg",
        snacks_only(function(picker)
          picker.lsp_definitions(ivy_opts())
        end),
        desc = "LSP Definition",
      },
      {
        "<leader>cc",
        snacks_only(function(picker)
          picker.lsp_incoming_calls(ivy_opts())
        end),
        desc = "LSP Incoming Calls",
      },
      {
        "<leader>ct",
        snacks_only(function(picker)
          picker.lsp_references(ivy_opts())
        end),
        desc = "LSP References",
      },
      {
        "<leader>cd",
        snacks_only(function(picker)
          picker.lsp_outgoing_calls(ivy_opts())
        end),
        desc = "LSP Outgoing Calls",
      },
      {
        "<leader>ce",
        snacks_only(function(picker)
          picker.grep(ivy_opts())
        end),
        desc = "Live Grep",
      },
      {
        "<leader>cf",
        snacks_only(function(picker)
          picker.files(ivy_opts())
        end),
        desc = "Find Files",
      },
      {
        "<leader>ci",
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
