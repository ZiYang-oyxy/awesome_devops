local M = {}
local list_ns = vim.api.nvim_create_namespace("kaleidosearch_list")
local match_ns = vim.api.nvim_create_namespace("kaleidosearch_matches")
local list_winid = nil
local stable_pattern_colors = {}
local refresh_augroup = vim.api.nvim_create_augroup("KaleidosearchDynamicRefresh", { clear = true })
local cmdline_augroup = vim.api.nvim_create_augroup("KaleidosearchCmdlineSync", { clear = true })
local jump_to_group
local runtime_regex_mode = true
local persist_key = "KALEIDOSEARCH_STATE"
local cmdline_sync_state = {
  active = false,
  snapshot_words = {},
  preview_pattern = "",
}

local function close_rules_window()
  if list_winid and vim.api.nvim_win_is_valid(list_winid) then
    vim.api.nvim_win_close(list_winid, true)
  end
  list_winid = nil
end

local function to_hex(color)
  return string.format("#%06x", color)
end

local function is_regex_mode()
  return runtime_regex_mode
end

local function clone_words(words)
  return vim.deepcopy(words or {})
end

local function trim_text(text)
  return (text or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function normalize_words(words)
  local normalized = {}
  for _, word in ipairs(words or {}) do
    if type(word) == "string" then
      local trimmed_word = trim_text(word)
      if trimmed_word ~= "" then
        table.insert(normalized, trimmed_word)
      end
    end
  end
  return normalized
end

local function save_kaleidosearch_state(words)
  local normalized_words = normalize_words(words)
  if #normalized_words == 0 then
    vim.g[persist_key] = nil
    return
  end

  local ok, encoded_state = pcall(vim.json.encode, {
    words = normalized_words,
    regex_mode = is_regex_mode(),
  })
  if ok and encoded_state then
    vim.g[persist_key] = encoded_state
  end
end

local function load_kaleidosearch_state()
  local raw_state = vim.g[persist_key]
  if type(raw_state) ~= "string" or raw_state == "" then
    return {}, nil
  end

  local ok, decoded_state = pcall(vim.json.decode, raw_state)
  if not ok or type(decoded_state) ~= "table" then
    vim.g[persist_key] = nil
    return {}, nil
  end

  local words = normalize_words(decoded_state.words)
  local regex_mode = type(decoded_state.regex_mode) == "boolean" and decoded_state.regex_mode or nil
  if #words == 0 then
    vim.g[persist_key] = nil
  end
  return words, regex_mode
end

local function normalize_pattern(pattern, case_sensitive, regex_mode)
  if not pattern then
    return ""
  end
  if regex_mode then
    return pattern
  end
  return case_sensitive and pattern or pattern:lower()
end

local function escape_literal_vim_pattern(text)
  return (text or ""):gsub("([\\%^%$%(%)%%%.%[%]%*%+%-%?%{%}%|])", "\\%1")
end

local function build_pattern_body(kaleidosearch, pattern, regex_mode)
  local body = regex_mode and pattern or escape_literal_vim_pattern(pattern)
  if kaleidosearch.config.whole_word_match then
    return "\\<" .. body .. "\\>"
  end
  return body
end

local function build_single_search_pattern(kaleidosearch, pattern, regex_mode)
  if not pattern or pattern == "" then
    return ""
  end
  local case_flag = kaleidosearch.config.case_sensitive and "\\C" or "\\c"
  return "\\m" .. case_flag .. build_pattern_body(kaleidosearch, pattern, regex_mode)
end

local function compile_regex(kaleidosearch, pattern, regex_mode)
  local search_pattern = build_single_search_pattern(kaleidosearch, pattern, regex_mode)
  if search_pattern == "" then
    return nil
  end
  local ok, compiled = pcall(vim.regex, search_pattern)
  if not ok then
    return nil
  end
  return compiled
end

local function for_each_pattern_match(line, compiled_regex, callback)
  local start_col = 0
  local line_len = #line
  while start_col <= line_len do
    local match_start, match_end = compiled_regex:match_str(line, start_col)
    if match_start == nil then
      break
    end
    callback(match_start, match_end)
    if match_end > start_col then
      start_col = match_end
    else
      start_col = start_col + 1
    end
  end
end

local function convert_word_highlight_to_bg()
  local kaleidosearch = require("kaleidosearch")
  local prefix = kaleidosearch.config.highlight_group_prefix or "WordColor_"
  local groups = vim.fn.getcompletion(prefix, "highlight")

  for _, group in ipairs(groups) do
    local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
    if highlight and highlight.fg then
      vim.api.nvim_set_hl(0, group, { bg = to_hex(highlight.fg) })
    end
  end
end

local function find_group_name_for_pattern(buffer, kaleidosearch, pattern, prefix)
  local regex_mode = is_regex_mode()
  local compiled_regex = compile_regex(kaleidosearch, pattern, regex_mode)
  if not compiled_regex then
    return nil
  end
  local search_lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)

  for line_nr, line in ipairs(search_lines) do
    local found_group = nil
    for_each_pattern_match(line, compiled_regex, function(match_start, match_end)
      local highlights = vim.api.nvim_buf_get_extmarks(
        buffer,
        -1,
        { line_nr - 1, match_start },
        { line_nr - 1, match_end },
        { details = true, overlap = true, type = "highlight", limit = 30 }
      )

      for _, mark in ipairs(highlights) do
        local details = mark[4] or {}
        local hl_group = details.hl_group
        if hl_group and hl_group:sub(1, #prefix) == prefix then
          found_group = hl_group
          return
        end
      end
    end)
    if found_group then
      return found_group
    end
  end

  return nil
end

local function extract_group_color(group_name)
  local highlight = vim.api.nvim_get_hl(0, { name = group_name, link = false })
  if highlight and highlight.bg then
    return to_hex(highlight.bg)
  end
  if highlight and highlight.fg then
    return to_hex(highlight.fg)
  end
  return nil
end

local function set_group_bg_color(group_name, color)
  vim.api.nvim_set_hl(0, group_name, { bg = color })
end

local function stabilize_word_colors(kaleidosearch, words)
  local buffer = vim.api.nvim_get_current_buf()
  local prefix = kaleidosearch.config.highlight_group_prefix or "WordColor_"
  local regex_mode = is_regex_mode()

  for _, pattern in ipairs(words or {}) do
    local group_name = find_group_name_for_pattern(buffer, kaleidosearch, pattern, prefix)
    if group_name then
      local pattern_key = normalize_pattern(pattern, kaleidosearch.config.case_sensitive, regex_mode)
      local cached_color = stable_pattern_colors[pattern_key]
      if cached_color then
        set_group_bg_color(group_name, cached_color)
      else
        local current_color = extract_group_color(group_name)
        if current_color then
          stable_pattern_colors[pattern_key] = current_color
        end
      end
    end
  end
end

local function build_global_search_pattern(kaleidosearch, words)
  local case_flag = kaleidosearch.config.case_sensitive and "\\C" or "\\c"
  local regex_mode = is_regex_mode()
  local patterns = {}

  for _, word in ipairs(words or {}) do
    if word ~= "" then
      local pattern_body = build_pattern_body(kaleidosearch, word, regex_mode)
      table.insert(patterns, "\\%(" .. pattern_body .. "\\)")
    end
  end

  if #patterns == 0 then
    return ""
  end
  return "\\m" .. case_flag .. "\\(" .. table.concat(patterns, "\\|") .. "\\)"
end

local function apply_colorization_regex(kaleidosearch, words_to_colorize)
  if not words_to_colorize or #words_to_colorize == 0 then
    return
  end

  local buffer = vim.api.nvim_get_current_buf()
  local regex_mode = is_regex_mode()
  local case_sensitive = kaleidosearch.config.case_sensitive
  local prefix = kaleidosearch.config.highlight_group_prefix or "WordColor_"
  local warned_invalid = {}

  vim.api.nvim_buf_clear_namespace(buffer, match_ns, 0, -1)
  vim.cmd("nohlsearch")

  local original_filetype = vim.bo.filetype
  vim.bo.filetype = "txt"

  for _, pattern in ipairs(words_to_colorize) do
    if pattern ~= "" then
      local compiled_regex = compile_regex(kaleidosearch, pattern, regex_mode)
      if not compiled_regex then
        if not warned_invalid[pattern] then
          warned_invalid[pattern] = true
          vim.notify(
            string.format("Invalid regex skipped: %s", pattern),
            vim.log.levels.WARN,
            { title = "Kaleidosearch Regex" }
          )
        end
      else
        local pattern_key = normalize_pattern(pattern, case_sensitive, regex_mode)
        if not stable_pattern_colors[pattern_key] then
          stable_pattern_colors[pattern_key] = kaleidosearch.config.get_next_color()
        end
        local color = stable_pattern_colors[pattern_key]
        local group_name = prefix .. kaleidosearch.config.sanitize_group_name(color)
        vim.api.nvim_set_hl(0, group_name, { fg = color })

        local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
        for line_nr, line in ipairs(lines) do
          for_each_pattern_match(line, compiled_regex, function(match_start, match_end)
            if match_end > match_start then
              vim.api.nvim_buf_set_extmark(buffer, match_ns, line_nr - 1, match_start, {
                end_col = match_end,
                hl_group = group_name,
                priority = 1000,
                hl_mode = "combine",
              })
            end
          end)
        end
      end
    end
  end

  local search_pattern = build_global_search_pattern(kaleidosearch, words_to_colorize)
  vim.fn.setreg("/", search_pattern)
  vim.cmd("nohlsearch")
  kaleidosearch.last_words = words_to_colorize

  if original_filetype ~= "" then
    vim.bo.filetype = original_filetype
  end
end

local function restore_global_search_register(kaleidosearch)
  local words = kaleidosearch.last_words or {}
  local global_pattern = build_global_search_pattern(kaleidosearch, words)
  vim.fn.setreg("/", global_pattern)
end

local function jump_like_n(pattern, forward)
  vim.fn.setreg("/", pattern)
  local set_direction_ok = pcall(function()
    vim.v.searchforward = forward and 1 or 0
  end)

  local ok
  if set_direction_ok then
    ok = pcall(vim.cmd, "normal! n")
  else
    ok = pcall(vim.cmd, "normal! " .. (forward and "n" or "N"))
  end
  if ok then
    local count = vim.fn.searchcount({ recompute = 1, maxcount = 0 })
    if count and count.total and count.total > 0 then
      vim.api.nvim_echo({ { string.format("[%d/%d]", count.current or 0, count.total) } }, false, {})
    end
  end
  vim.cmd("nohlsearch")
  return ok
end

local function show_matching_rules()
  local kaleidosearch = require("kaleidosearch")
  local words = kaleidosearch.last_words or {}
  local source_buffer = vim.api.nvim_get_current_buf()

  if #words == 0 then
    vim.notify("No matching rules.", vim.log.levels.INFO, { title = "Kaleidosearch Rules" })
    return
  end

  local lines = {}
  for _, pattern in ipairs(words) do
    lines[#lines + 1] = pattern
  end

  close_rules_window()

  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].filetype = "kaleidosearch_rules"
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(math.max(width + 4, 30), math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines, math.floor(vim.o.lines * 0.7))
  local row = math.floor((vim.o.lines - height) / 2 - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  list_winid = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    row = math.max(row, 1),
    col = math.max(col, 0),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Kaleidosearch Rules ",
    title_pos = "center",
  })

  vim.wo[list_winid].wrap = false
  vim.wo[list_winid].cursorline = true

  local prefix = kaleidosearch.config.highlight_group_prefix or "WordColor_"
  for index, pattern in ipairs(words) do
    local group_name = find_group_name_for_pattern(source_buffer, kaleidosearch, pattern, prefix)

    if group_name then
      vim.api.nvim_buf_add_highlight(buffer, list_ns, group_name, index - 1, 0, -1)
    end
  end

  vim.keymap.set("n", "q", function()
    close_rules_window()
  end, { buffer = buffer, silent = true, nowait = true })

  vim.keymap.set("n", "<esc>", function()
    close_rules_window()
  end, { buffer = buffer, silent = true, nowait = true })

  vim.keymap.set("n", "<cr>", function()
    local cursor = vim.api.nvim_win_get_cursor(list_winid)
    local line = cursor[1]
    local index = line
    if index < 1 or index > #words then
      return
    end
    close_rules_window()
    jump_to_group(index)
  end, { buffer = buffer, silent = true, nowait = true })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "InsertEnter" }, {
    buffer = buffer,
    once = true,
    callback = function()
      close_rules_window()
    end,
  })
end

jump_to_group = function(index)
  local kaleidosearch = require("kaleidosearch")
  local words = kaleidosearch.last_words or {}
  if #words == 0 then
    vim.notify("No matching rules.", vim.log.levels.WARN, { title = "Kaleidosearch Jump" })
    return
  end

  local resolved_index = ((index - 1) % #words) + 1
  local pattern = words[resolved_index]

  if not pattern or pattern == "" then
    vim.notify(string.format("Group %d has no pattern.", index), vim.log.levels.WARN, { title = "Kaleidosearch Jump" })
    return
  end

  local single_pattern = build_single_search_pattern(kaleidosearch, pattern, is_regex_mode())
  jump_like_n(single_pattern, true)

  restore_global_search_register(kaleidosearch)
end

local get_current_visual_selection

local function leave_visual_mode()
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "n", false)
end

local function mark_word_or_selection()
  local kaleidosearch = require("kaleidosearch")
  local mode = vim.fn.mode()

  if mode == "v" or mode == "V" or mode == "\22" then
    local selected_text, selection_err = get_current_visual_selection()
    if selection_err == "block_not_supported" then
      vim.notify("Visual block mode is not supported for KaleidoSearch mark.", vim.log.levels.WARN, {
        title = "Kaleidosearch Visual",
      })
      leave_visual_mode()
      return
    end
    if selected_text and selected_text ~= "" then
      kaleidosearch.toggle_word(selected_text)
    end
    leave_visual_mode()
    return
  end

  local word = vim.fn.expand("<cword>")
  if word and word ~= "" then
    kaleidosearch.toggle_word(word)
  end
end

get_current_visual_selection = function()
  local mode_now = vim.fn.mode(1)
  local visual_type = mode_now:sub(1, 1)
  if visual_type ~= "v" and visual_type ~= "V" and visual_type ~= "\22" then
    visual_type = vim.fn.visualmode()
  end

  if visual_type == "\22" then
    return nil, "block_not_supported"
  end

  local anchor_pos = vim.fn.getpos("v")
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local start_row, start_col = anchor_pos[2] - 1, anchor_pos[3] - 1
  local end_row, end_col = cursor_pos[1] - 1, cursor_pos[2]

  if start_row < 0 or end_row < 0 then
    return ""
  end

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  if visual_type == "V" then
    start_col = 0
    local end_line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or ""
    end_col = #end_line
  else
    end_col = end_col + 1
  end

  local chunks = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
  local selection = table.concat(chunks, "\n")
  return selection:gsub("[\n\r]", " "):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
end

local function mark_visual_selection()
  local kaleidosearch = require("kaleidosearch")
  local selected_text, selection_err = get_current_visual_selection()
  if selection_err == "block_not_supported" then
    vim.notify("Visual block mode is not supported for KaleidoSearch mark.", vim.log.levels.WARN, {
      title = "Kaleidosearch Visual",
    })
    leave_visual_mode()
    return
  end
  if selected_text and selected_text ~= "" then
    kaleidosearch.toggle_word(selected_text)
  end
  leave_visual_mode()
end

local function get_active_pattern_under_cursor()
  local kaleidosearch = require("kaleidosearch")
  local words = kaleidosearch.last_words or {}
  if #words == 0 then
    return nil
  end

  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local col = cursor[2]
  local regex_mode = is_regex_mode()

  local matched_pattern = nil
  local matched_length = -1

  for _, pattern in ipairs(words) do
    local compiled_regex = compile_regex(kaleidosearch, pattern, regex_mode)
    if compiled_regex then
      for_each_pattern_match(line, compiled_regex, function(match_start, match_end)
        if col >= match_start and col < match_end then
          local pattern_length = match_end - match_start
          if pattern_length > matched_length then
            matched_pattern = pattern
            matched_length = pattern_length
          end
        end
      end)
    end
  end

  return matched_pattern
end

local function jump_by_current_pattern(forward)
  local kaleidosearch = require("kaleidosearch")
  local words = kaleidosearch.last_words or {}
  if #words == 0 then
    vim.notify("No matching rules.", vim.log.levels.WARN, { title = "Kaleidosearch Jump" })
    return
  end

  local pattern = get_active_pattern_under_cursor()
  local match_ok = false
  if pattern and pattern ~= "" then
    local single_pattern = build_single_search_pattern(kaleidosearch, pattern, is_regex_mode())
    match_ok = jump_like_n(single_pattern, forward)
  else
    local global_pattern = build_global_search_pattern(kaleidosearch, words)
    if global_pattern ~= "" then
      match_ok = jump_like_n(global_pattern, forward)
    end
  end

  restore_global_search_register(kaleidosearch)
  if not match_ok then
    vim.notify("No match found.", vim.log.levels.WARN, { title = "Kaleidosearch Jump" })
  end
end

local function refresh_matches_if_needed()
  local kaleidosearch = require("kaleidosearch")
  local words = kaleidosearch.last_words or {}
  if #words == 0 then
    return
  end

  if vim.bo.buftype ~= "" then
    return
  end

  kaleidosearch.apply_colorization(words)
end

local function apply_preview_words(words)
  local kaleidosearch = require("kaleidosearch")
  local preserved_words = clone_words(kaleidosearch.last_words or {})
  kaleidosearch.apply_colorization(clone_words(words))
  kaleidosearch.last_words = preserved_words
end

local function restore_snapshot_matches()
  local kaleidosearch = require("kaleidosearch")
  local snapshot_words = cmdline_sync_state.snapshot_words or {}
  if #snapshot_words > 0 then
    kaleidosearch.apply_colorization(clone_words(snapshot_words))
    kaleidosearch.last_words = clone_words(snapshot_words)
    save_kaleidosearch_state(kaleidosearch.last_words)
  else
    kaleidosearch.clear_all_highlights()
    kaleidosearch.last_words = {}
  end
end

local function sync_matches_from_search_cmdline()
  local cmd_type = vim.fn.getcmdtype()
  if cmd_type ~= "/" and cmd_type ~= "?" then
    return
  end

  local input = vim.fn.getcmdline()
  local pattern = trim_text(input)
  cmdline_sync_state.preview_pattern = pattern

  if pattern == "" then
    restore_snapshot_matches()
    return
  end

  apply_preview_words({ pattern })
end

M.show_matching_rules = show_matching_rules
M.jump_to_group = jump_to_group
M.mark_word_or_selection = mark_word_or_selection
M.mark_visual_selection = mark_visual_selection
M.jump_prev_current_match = function()
  jump_by_current_pattern(false)
end
M.jump_next_current_match = function()
  jump_by_current_pattern(true)
end

function M.setup(opts)
  opts = opts or {}
  runtime_regex_mode = opts.regex_mode ~= false
  local kaleidosearch = require("kaleidosearch")
  kaleidosearch.setup({
    case_sensitive = true,
    keymaps = {
      enabled = false,
    },
  })

  local original_apply_colorization = kaleidosearch.apply_colorization
  local original_clear_all_highlights = kaleidosearch.clear_all_highlights
  kaleidosearch.apply_colorization = function(words_to_colorize)
    local original_filetype = vim.bo.filetype
    local result
    if is_regex_mode() then
      result = apply_colorization_regex(kaleidosearch, words_to_colorize)
    else
      result = original_apply_colorization(words_to_colorize)
    end
    if original_filetype ~= "" and vim.bo.filetype ~= original_filetype then
      vim.bo.filetype = original_filetype
    end
    convert_word_highlight_to_bg()
    stabilize_word_colors(kaleidosearch, kaleidosearch.last_words or {})
    if not cmdline_sync_state.active then
      save_kaleidosearch_state(kaleidosearch.last_words or {})
    end
    return result
  end
  kaleidosearch.clear_all_highlights = function()
    original_clear_all_highlights()
    local buffer = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buffer, match_ns, 0, -1)
    vim.fn.setreg("/", "")
    vim.cmd("nohlsearch")
    kaleidosearch.last_words = {}
    save_kaleidosearch_state({})
  end

  vim.api.nvim_create_user_command("KaleidosearchList", function()
    show_matching_rules()
  end, {
    desc = "Show current KaleidoSearch matching rules",
  })

  vim.api.nvim_create_user_command("KaleidosearchMark", function()
    mark_word_or_selection()
  end, {
    desc = "Mark cursor word or visual selection",
  })

  vim.api.nvim_create_user_command("KaleidosearchJumpGroup", function(args)
    local index = tonumber(args.args)
    if not index then
      vim.notify("Usage: :KaleidosearchJumpGroup {index}", vim.log.levels.WARN, { title = "Kaleidosearch Jump" })
      return
    end
    jump_to_group(index)
  end, {
    nargs = 1,
    desc = "Jump to pattern by group index",
  })

  vim.api.nvim_create_user_command("KaleidosearchRegexMode", function(args)
    local value = (args.args or ""):lower()
    if value == "" then
      vim.notify(
        string.format("Kaleidosearch regex mode: %s", is_regex_mode() and "on" or "off"),
        vim.log.levels.INFO,
        { title = "Kaleidosearch Regex" }
      )
      return
    end

    if value == "on" then
      runtime_regex_mode = true
    elseif value == "off" then
      runtime_regex_mode = false
    elseif value == "toggle" then
      runtime_regex_mode = not runtime_regex_mode
    else
      vim.notify(
        "Usage: :KaleidosearchRegexMode [on|off|toggle]",
        vim.log.levels.WARN,
        { title = "Kaleidosearch Regex" }
      )
      return
    end

    vim.notify(
      string.format("Kaleidosearch regex mode: %s", is_regex_mode() and "on" or "off"),
      vim.log.levels.INFO,
      { title = "Kaleidosearch Regex" }
    )

    local words = kaleidosearch.last_words or {}
    if #words > 0 then
      kaleidosearch.apply_colorization(clone_words(words))
      kaleidosearch.last_words = clone_words(words)
      save_kaleidosearch_state(kaleidosearch.last_words)
    end
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "toggle" }
    end,
    desc = "Set KaleidoSearch regex mode",
  })

  vim.api.nvim_clear_autocmds({ group = refresh_augroup })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = refresh_augroup,
    callback = function()
      refresh_matches_if_needed()
    end,
    desc = "Refresh KaleidoSearch highlights after text changes",
  })

  vim.api.nvim_clear_autocmds({ group = cmdline_augroup })
  vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = cmdline_augroup,
    callback = function()
      local cmd_type = vim.fn.getcmdtype()
      if cmd_type ~= "/" and cmd_type ~= "?" then
        return
      end
      local words = kaleidosearch.last_words or {}
      cmdline_sync_state.active = true
      cmdline_sync_state.snapshot_words = clone_words(words)
      cmdline_sync_state.preview_pattern = ""
    end,
    desc = "Snapshot KaleidoSearch words before / or ?",
  })
  vim.api.nvim_create_autocmd("CmdlineChanged", {
    group = cmdline_augroup,
    callback = function()
      if not cmdline_sync_state.active then
        return
      end
      vim.schedule(function()
        sync_matches_from_search_cmdline()
      end)
    end,
    desc = "Sync KaleidoSearch highlights while typing / or ?",
  })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = cmdline_augroup,
    callback = function()
      if not cmdline_sync_state.active then
        return
      end
      local kaleidosearch = require("kaleidosearch")
      local event = vim.v.event or {}
      local is_abort = event.abort == true
      local pattern = trim_text(cmdline_sync_state.preview_pattern)

      if not is_abort and pattern ~= "" then
        local current_words = { pattern }
        kaleidosearch.apply_colorization(current_words)
        kaleidosearch.last_words = clone_words(current_words)
        save_kaleidosearch_state(kaleidosearch.last_words)
        vim.schedule(function()
          restore_global_search_register(kaleidosearch)
          vim.cmd("nohlsearch")
        end)
      else
        restore_snapshot_matches()
      end

      cmdline_sync_state.active = false
      cmdline_sync_state.snapshot_words = {}
      cmdline_sync_state.preview_pattern = ""
    end,
    desc = "Stop cmdline sync after / or ?",
  })

  local restored_words, restored_regex_mode = load_kaleidosearch_state()
  if type(restored_regex_mode) == "boolean" then
    runtime_regex_mode = restored_regex_mode
  end
  if #restored_words > 0 then
    kaleidosearch.apply_colorization(clone_words(restored_words))
    kaleidosearch.last_words = clone_words(restored_words)
    restore_global_search_register(kaleidosearch)
    vim.cmd("nohlsearch")
  end
end

return M
