local opts = require('matchparen.options').opts
local utils = require('matchparen.utils')
local search = require('matchparen.search')
local bouncer = require('matchparen.debounce')

local hl = {}
local extmarks = {}
local namespace = vim.api.nvim_create_namespace(opts.augroup_name)

---Wrapper for nvim_buf_set_extmark()
---@param bufnr integer buffer number
---@param line integer 0-based line number
---@param col integer 0-based column number
local function set_extmark(bufnr, line, col)
  return vim.api.nvim_buf_set_extmark(bufnr, namespace, line, col,
    { end_col = col + 1, hl_group = opts.hl_group })
end

---Add brackets highlight
---@param bufnr integer buffer number
---@param curline integer 0-based line number
---@param curcol integer 0-based column number
---@param matchline integer 0-based line number
---@param matchcol integer 0-based column number
local function hl_add(bufnr, curline, curcol, matchline, matchcol)
  local extmark = extmarks[bufnr]
  if not extmark then
    extmarks[bufnr] = {}
    extmark = extmarks[bufnr]
  end

  local ok, ret = pcall(set_extmark, bufnr, curline, curcol)
  if ok then
    extmark.current = ret
  end

  local ok, ret = pcall(set_extmark, bufnr, matchline, matchcol)
  if ok then
    extmark.match = ret
  end
end

---Removes brackets highlight by deleting buffer extmarks
---@param bufnr integer buffer number
function hl.remove(bufnr)
  local extmark = extmarks[bufnr]
  if not extmark then
    return
  end

  if extmark.current then
    vim.api.nvim_buf_del_extmark(bufnr, namespace, extmark.current)
    extmark.current = nil
  end

  if extmark.match then
    vim.api.nvim_buf_del_extmark(bufnr, namespace, extmark.match)
    extmark.match = nil
  end

  if not extmark.match and not extmark.current then
    extmarks[bufnr] = nil
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
---@param bufnr integer? buffer number
hl.update = bouncer.throttle_trailing(opts.debounce_time, true, vim.schedule_wrap(function(in_insert, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  hl.remove(bufnr)

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
    hl_add(bufnr, line, col, matchline, matchcol or 0)
  end
end))

function hl.reset()
  for _bufnr, _ in pairs(extmarks or {}) do
    hl.remove(_bufnr)
  end
end

return hl

-- vim:sw=2:et
