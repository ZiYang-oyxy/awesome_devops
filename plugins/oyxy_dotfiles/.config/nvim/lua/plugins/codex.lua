return {
  {
    "rhart92/codex.nvim",
    opts = {
      split = "vertical",
      size = 0.5,
      float = {
        width = 0.6,
        height = 0.6,
        border = "rounded",
        row = nil,
        col = nil,
        title = "Codex",
      },
      codex_cmd = { "codex", "-m", "gpt-5.3-codex", "-c", 'model_reasoning_effort="medium"' },
      focus_after_send = false,
      log_level = "warn",
      autostart = false,
    },
    config = function(_, opts)
      local codex = require("codex")
      codex.setup(opts)

      local function switch_to_current_file_dir()
        local file_path = vim.api.nvim_buf_get_name(0)
        if file_path == "" then
          return
        end

        local dir = vim.fn.fnamemodify(file_path, ":p:h")
        if dir == "" or vim.fn.isdirectory(dir) == 0 then
          return
        end

        vim.cmd("lcd " .. vim.fn.fnameescape(dir))
      end

      local open = codex.open
      codex.open = function(...)
        switch_to_current_file_dir()
        return open(...)
      end

      local toggle = codex.toggle
      codex.toggle = function(...)
        switch_to_current_file_dir()
        return toggle(...)
      end

      local function normalize_column(bufnr, line, col, is_end)
        if col < 0 then
          return col
        end
        local line_text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
        if col == 2147483647 then
          return #line_text
        end
        local zero_based = math.max(col - 1, 0)
        if is_end then
          zero_based = math.min(zero_based + 1, #line_text)
        else
          zero_based = math.min(zero_based, #line_text)
        end
        return zero_based
      end

      local function get_visual_selection_fixed()
        local bufnr = vim.api.nvim_get_current_buf()
        local mode = vim.fn.mode()
        local needs_restore = false

        if not mode:match("^[vV\22]") then
          local ok = pcall(vim.cmd, [[normal! gv]])
          if not ok then
            return nil
          end
          mode = vim.fn.mode()
          needs_restore = true
        end

        local selection_type = vim.fn.visualmode()
        if selection_type == nil or selection_type == "" then
          selection_type = mode
        end
        selection_type = selection_type:sub(1, 1)

        local start_pos = vim.fn.getpos("v")
        local end_pos = vim.fn.getpos(".")
        if start_pos[2] == 0 or end_pos[2] == 0 then
          if needs_restore or mode:match("^[vV\22]") then
            pcall(vim.cmd, "normal! \\27")
          end
          return nil
        end

        if needs_restore or mode:match("^[vV\22]") then
          pcall(vim.cmd, "normal! \\27")
        end

        local start_line, start_col = start_pos[2], start_pos[3]
        local end_line, end_col = end_pos[2], end_pos[3]

        if start_line > end_line or (start_line == end_line and start_col > end_col) then
          start_line, end_line = end_line, start_line
          start_col, end_col = end_col, start_col
        end

        local text
        if selection_type == "V" then
          local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
          text = table.concat(lines, "\n")
        elseif selection_type == "\22" then
          local left = math.min(start_col, end_col) - 1
          local right = math.max(start_col, end_col) - 1
          local pieces = {}
          for row = start_line - 1, end_line - 1 do
            local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
            pieces[#pieces + 1] = line:sub(left + 1, math.min(right + 1, #line))
          end
          text = table.concat(pieces, "\n")
        else
          local start_c = normalize_column(bufnr, start_line, start_col, false)
          local end_c = normalize_column(bufnr, end_line, end_col, true)
          local lines = vim.api.nvim_buf_get_text(bufnr, start_line - 1, start_c, end_line - 1, end_c, {})
          text = table.concat(lines, "\n")
        end

        if text == "" then
          return nil
        end

        if vim.bo.expandtab then
          local tabstop = vim.bo.tabstop
          if tabstop and tabstop > 0 then
            text = text:gsub("\t", string.rep(" ", tabstop))
          end
        end

        return {
          bufnr = bufnr,
          start_line = start_line,
          end_line = end_line,
          text = text,
        }
      end

      codex.actions.send_selection = function()
        local selection = get_visual_selection_fixed()
        if not selection or not selection.text or selection.text == "" then
          vim.notify("codex.nvim: visual selection is empty", vim.log.levels.WARN)
          return
        end

        switch_to_current_file_dir()

        local filename = vim.api.nvim_buf_get_name(selection.bufnr)
        if filename == "" then
          filename = "[No Name]"
        else
          filename = vim.fn.fnamemodify(filename, ":t")
        end

        local payload = string.format("File: %s:%d-%d\n\n", filename, selection.start_line, selection.end_line)
          .. selection.text
        if payload:sub(-1) ~= "\n" then
          payload = payload .. " \n\n"
        end

        codex.actions.send(payload, { submit = false })
      end
    end,
  },
}
