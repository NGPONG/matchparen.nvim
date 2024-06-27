local opts = require('matchparen.options').opts
local utils = require('matchparen.utils')
local search = require('matchparen.search')

local hl = {}
local namespace = vim.api.nvim_create_namespace(opts.augroup_name)
local extmarks = { current = 0, match = 0 }

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
  if utils.is_in_insert_mode() then
    local ok, ret = pcall(set_extmark, curline, curcol)
    if ok then
      extmarks.current = ret
    end
  end

  local ok, ret = pcall(set_extmark, matchline, matchcol)
  if ok then
    extmarks.match = ret
  end
end

---Removes brackets highlight by deleting buffer extmarks
function hl.remove()
  if extmarks.current then
    vim.api.nvim_buf_del_extmark(0, namespace, extmarks.current)
    extmarks.current = nil
  end

  if extmarks.match then
    vim.api.nvim_buf_del_extmark(0, namespace, extmarks.match)
    extmarks.match = nil
  end
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
  hl.remove()

  local line, col = utils.get_cursor_pos()
  if utils.is_inside_fold(line) then
    return
  end

  local match_bracket
  match_bracket, col = get_bracket(col, in_insert)
  if not match_bracket then
    return
  end

  local matchline, matchcol = search.match_pos(match_bracket, line, col)
  if matchline then
    hl_add(line, col, matchline, matchcol or 0)
  end
end

return hl

-- vim:sw=2:et
