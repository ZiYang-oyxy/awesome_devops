---@diagnostic disable: undefined-global

local M = {}

local uv = vim.uv or vim.loop
local STORE_VERSION = 1
local STORE_FILENAME = "snacks-explorer-bookmarks.json"

local state = {
  loaded = false,
  data = { version = STORE_VERSION, items = {} },
  save_lock = false,
  save_pending = false,
}

local function notify(level, msg)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks and snacks.notify and snacks.notify[level] then
    snacks.notify[level](msg)
    return
  end

  local levels = {
    info = vim.log.levels.INFO,
    warn = vim.log.levels.WARN,
    error = vim.log.levels.ERROR,
  }
  vim.notify(msg, levels[level] or vim.log.levels.INFO)
end

local function store_path()
  return vim.fs.normalize(vim.fn.stdpath("data") .. "/" .. STORE_FILENAME)
end

local function now()
  return os.time()
end

local function normalize_path(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  local abs = vim.fn.fnamemodify(path, ":p")
  if abs == "" then
    return nil
  end
  return vim.fs.normalize(abs)
end

local function is_file(path)
  if not path then
    return false
  end
  return vim.fn.filereadable(path) == 1 and vim.fn.isdirectory(path) == 0
end

local function find_index(path)
  for idx, item in ipairs(state.data.items) do
    if item.path == path then
      return idx
    end
  end
end

local function write_file_atomic(path, content)
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local tmp = path .. ".tmp"
  local f, err = io.open(tmp, "w")
  if not f then
    return false, err or "failed to open temp file"
  end

  local ok_write, write_err = pcall(f.write, f, content)
  local ok_close, close_err = pcall(f.close, f)
  if not ok_write or not ok_close then
    pcall(vim.fn.delete, tmp)
    return false, tostring(write_err or close_err or "failed to write temp file")
  end

  local renamed = false
  if uv and uv.fs_rename then
    local ok_rename = uv.fs_rename(tmp, path)
    renamed = ok_rename == true
  end
  if not renamed then
    renamed = vim.fn.rename(tmp, path) == 0
  end

  if not renamed then
    pcall(vim.fn.delete, tmp)
    return false, "failed to replace bookmark store file"
  end
  return true
end

local function sanitize_items(raw_items)
  local out = {} ---@type {path:string, added_at:integer, last_used_at:integer}[]
  local index = {} ---@type table<string, integer>
  for _, item in ipairs(type(raw_items) == "table" and raw_items or {}) do
    if type(item) == "table" then
      local path = normalize_path(item.path)
      if path and is_file(path) then
        local added_at = tonumber(item.added_at) or now()
        local last_used_at = tonumber(item.last_used_at) or added_at
        local idx = index[path]
        if idx then
          out[idx].added_at = math.min(out[idx].added_at, added_at)
          out[idx].last_used_at = math.max(out[idx].last_used_at, last_used_at)
        else
          index[path] = #out + 1
          out[#out + 1] = { path = path, added_at = added_at, last_used_at = last_used_at }
        end
      end
    end
  end

  return out
end

local function backup_corrupted_store(path, raw)
  local backup = path .. ".broken." .. os.date("%Y%m%d%H%M%S")
  local renamed = false
  if uv and uv.fs_rename then
    renamed = uv.fs_rename(path, backup) == true
  end
  if not renamed then
    renamed = vim.fn.rename(path, backup) == 0
  end
  if not renamed and raw and raw ~= "" then
    write_file_atomic(backup, raw)
  end
  notify("warn", "Bookmarks store was corrupted and has been reset")
end

local function prune_invalid_items()
  M.load()
  local before = vim.json.encode(state.data.items)
  state.data.items = sanitize_items(state.data.items)
  return before ~= vim.json.encode(state.data.items)
end

local function save_now()
  M.load()
  local payload = vim.json.encode({
    version = STORE_VERSION,
    items = state.data.items,
  })
  local ok, err = write_file_atomic(store_path(), payload)
  if not ok then
    notify("error", "Failed to save bookmarks: " .. tostring(err))
  end
end

function M.load()
  if state.loaded then
    return state.data
  end

  local path = store_path()
  local f = io.open(path, "r")
  if not f then
    state.loaded = true
    state.data = { version = STORE_VERSION, items = {} }
    return state.data
  end

  local raw = f:read("*a") or ""
  f:close()
  if raw == "" then
    state.loaded = true
    state.data = { version = STORE_VERSION, items = {} }
    return state.data
  end

  local ok_decode, decoded = pcall(vim.json.decode, raw)
  if not ok_decode or type(decoded) ~= "table" then
    backup_corrupted_store(path, raw)
    state.loaded = true
    state.data = { version = STORE_VERSION, items = {} }
    M.save()
    return state.data
  end

  local sanitized = sanitize_items(decoded.items)
  state.data = {
    version = STORE_VERSION,
    items = sanitized,
  }
  state.loaded = true

  if tonumber(decoded.version) ~= STORE_VERSION or #sanitized ~= #(decoded.items or {}) then
    M.save()
  end
  return state.data
end

function M.save()
  if state.save_lock then
    state.save_pending = true
    return
  end

  state.save_lock = true
  local ok_save, err = pcall(save_now)
  state.save_lock = false
  if not ok_save then
    notify("error", "Failed to save bookmarks: " .. tostring(err))
  end

  if state.save_pending then
    state.save_pending = false
    M.save()
  end
end

function M.has(path)
  local target = normalize_path(path)
  if not target then
    return false
  end
  M.load()
  return find_index(target) ~= nil
end

function M.toggle(path)
  local target = normalize_path(path)
  if not target or not is_file(target) then
    return nil, "not_file"
  end

  M.load()
  local idx = find_index(target)
  if idx then
    table.remove(state.data.items, idx)
    M.save()
    return { added = false, path = target }
  end

  local ts = now()
  state.data.items[#state.data.items + 1] = {
    path = target,
    added_at = ts,
    last_used_at = ts,
  }
  M.save()
  return { added = true, path = target }
end

function M.remove(path)
  local target = normalize_path(path)
  if not target then
    return false
  end

  M.load()
  local idx = find_index(target)
  if not idx then
    return false
  end
  table.remove(state.data.items, idx)
  M.save()
  return true
end

function M.touch(path)
  local target = normalize_path(path)
  if not target then
    return false
  end

  M.load()
  local idx = find_index(target)
  if not idx then
    return false
  end
  if not is_file(target) then
    return false
  end

  state.data.items[idx].last_used_at = now()
  M.save()
  return true
end

function M.list()
  M.load()
  local changed = prune_invalid_items()
  local items = vim.deepcopy(state.data.items)
  table.sort(items, function(a, b)
    if a.last_used_at == b.last_used_at then
      if a.added_at == b.added_at then
        return a.path < b.path
      end
      return a.added_at > b.added_at
    end
    return a.last_used_at > b.last_used_at
  end)
  if changed then
    M.save()
  end
  return items
end

function M.next(current_path)
  local items = M.list()
  if #items == 0 then
    return nil
  end

  local current = normalize_path(current_path)
  if not current then
    return items[1].path
  end

  for i, item in ipairs(items) do
    if item.path == current then
      return items[(i % #items) + 1].path
    end
  end
  return items[1].path
end

function M.inline_items()
  local ret = {} ---@type snacks.picker.finder.Item[]
  for _, item in ipairs(M.list()) do
    ret[#ret + 1] = {
      file = item.path,
      text = item.path,
      label = "",
      oyxy_bookmark = true,
    }
  end
  return ret
end

local function get_item(picker, item)
  if item then
    return item
  end
  if picker and picker.current then
    return picker:current()
  end
  return nil
end

function M.explorer_bookmark_toggle(picker, item)
  local target = get_item(picker, item)
  if not (target and target.file) then
    return
  end
  if target.dir or vim.fn.isdirectory(target.file) == 1 then
    notify("warn", "Bookmarks only support files")
    return
  end

  local ret = M.toggle(target.file)
  if not ret then
    notify("warn", "Failed to toggle bookmark for current item")
    return
  end

  if ret.added then
    notify("info", "Bookmarked file: " .. ret.path)
  else
    notify("info", "Removed bookmark: " .. ret.path)
  end

  local ok_actions, actions = pcall(require, "snacks.explorer.actions")
  if ok_actions and actions and actions.update then
    actions.update(picker, { target = target.file, refresh = true })
  end
end

function M.explorer_bookmark_next(picker, item)
  local current = get_item(picker, item)
  local next_path = M.next(current and current.file or nil)
  if not next_path then
    notify("warn", "No bookmarks available")
    return
  end

  M.touch(next_path)
  local ok_actions, actions = pcall(require, "snacks.explorer.actions")
  if ok_actions and actions and actions.update then
    actions.update(picker, { target = next_path, refresh = true })
  end
end

function M.explorer_bookmark_refresh(picker)
  local target = get_item(picker, nil)
  local ok_actions, actions = pcall(require, "snacks.explorer.actions")
  if ok_actions and actions and actions.update then
    actions.update(picker, { target = target and target.file or false, refresh = true })
  end
end

function M.make_explorer_actions()
  return {
    explorer_bookmark_toggle = {
      action = M.explorer_bookmark_toggle,
      desc = "Toggle file bookmark",
    },
    explorer_bookmark_next = {
      action = M.explorer_bookmark_next,
      desc = "Jump to next bookmark file",
    },
    explorer_bookmark_refresh = {
      action = M.explorer_bookmark_refresh,
      desc = "Refresh inline bookmarks",
    },
  }
end

return M
