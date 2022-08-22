local opts = require('matchparen.options').opts
local utils = require('matchparen.utils')
local search = require('matchparen.search')

local hl = {}
local namespace = vim.api.nvim_create_namespace(opts.augroup_name)
local extmarks = { current = 0, match = 0 }
local matchparen_tick

---Wrapper for nvim_buf_set_extmark()
---@param line integer 0-based line number
---@param col integer 0-based column number
local function set_extmark(line, col)
  return vim.api.nvim_buf_set_extmark(0, namespace, line, col,
    { end_col = col + 1, hl_group = opts.hl_group })
end

---Add brackets highlight
---@param curline integer 0-based line number
---@param curcol integer 0-based column number
---@param matchline integer 0-based line number
---@param matchcol integer 0-based column number
local function hl_add(curline, curcol, matchline, matchcol)
  extmarks.current = set_extmark(curline, curcol)
  extmarks.match = set_extmark(matchline, matchcol)
end

---Removes brackets highlight by deleting buffer extmarks
function hl.remove()
  vim.api.nvim_buf_del_extmark(0, namespace, extmarks.current)
  vim.api.nvim_buf_del_extmark(0, namespace, extmarks.match)
end

---Returns matched bracket option and its column or nil
---@param col integer 0-based column number
---@param in_insert boolean
---@return table|nil, integer
local function get_bracket(col, in_insert)
  local text = vim.api.nvim_get_current_line()
  in_insert = in_insert or utils.is_in_insert_mode()

  if col > 0 and in_insert then
    local before_char = text:sub(col, col)
    if opts.matchpairs[before_char] then
      return opts.matchpairs[before_char], col - 1
    end
  end

  local inc_col = col + 1
  local cursor_char = text:sub(inc_col, inc_col)
  return opts.matchpairs[cursor_char], col
end

---Updates the highlight of brackets by first removing previous highlight
---and then if there is matching brackets pair at the new cursor position highlight them
---@param in_insert boolean
function hl.update(in_insert)
  matchparen_tick = vim.api.nvim_buf_get_changedtick(0)
  local line, col = utils.get_cursor_pos()
  if utils.is_inside_fold(line) then
    hl.remove()
    return
  end

  local match_bracket
  match_bracket, col = get_bracket(col, in_insert)
  if not match_bracket then
    hl.remove()
    return
  end

  local matchline, matchcol = search.match_pos(match_bracket, line, col)
  hl.remove()
  if matchline then
    hl_add(line, col, matchline, matchcol)
  end
end

---Updates highlighting only if changedtick is changed
---currently used only for TextChanged and TextChangedI autocmds
---so they do not repeat `update()` function after CursorMoved autocmds
function hl.update_on_tick()
  if matchparen_tick ~= vim.api.nvim_buf_get_changedtick(0) then
    hl.update(false)
  end
end

return hl

-- vim:sw=2:et
