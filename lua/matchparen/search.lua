local syntax = require('matchparen.syntax')
local ts = require('matchparen.treesitter')
local utils = require('matchparen.utils')

local M = {}

-- Determines whether a search should stop if searched line outside of range
-- @param line number (0-based) line number
-- @param backward boolean direction of the search
-- @return boolean
local function limit_by_line(line, backward)
    local stop
    local stopline
    local win_height = vim.api.nvim_win_get_height(0)
    if backward then
        stopline = line - win_height
        stop = function(l)
            return l < stopline
        end
    else
        stopline = line + win_height
        stop = function(l)
            return l > stopline
        end
    end
    return stop
end

function M.char(char, line, col, backward, skip, stop)
    local index
    col = col + 1
    stop = stop or function() end
    skip = skip or function() end
    local ok, to_skip
    local next_line
    local find_char
    local get_line_text
    if backward then
        next_line = utils.decrement
        find_char = utils.find_backward_char
        get_line_text = utils.get_reversed_line
    else
        next_line = utils.increment
        find_char = utils.find_forward_char
        get_line_text = utils.get_line
    end
    local text = get_line_text(line)

    repeat
        index = find_char(text, char, col)

        if index then
            col = index
            index = index - 1

            ok, to_skip = pcall(skip, line, index)
            if not ok then return end

            if not to_skip then
                if stop(line, index) then return end
                return line, index
            end
        else
            col = nil
            line = next_line(line)
            text = get_line_text(line)
        end
    until not text or stop(line, col)
end

-- Returns line and column of a matched bracket
-- @param matchpair table
-- @param line number (0-based) line number
-- @param col number (0-based) column number
-- @param skip function
-- @param stop function
-- @return (number, number) or nil
function M.pair(matchpair, line, col, skip, stop)
    local count = 0
    local index, bracket
    local chars = matchpair.right .. matchpair.left
    col = col + 1
    stop = stop or function() end
    skip = skip or function() end
    local ok, to_skip
    local same_bracket
    local next_line
    local find_char
    local get_line_text
    if matchpair.backward then
        same_bracket = matchpair.right
        next_line = utils.decrement
        find_char = utils.find_backward_char
        get_line_text = utils.get_reversed_line
    else
        same_bracket = matchpair.left
        next_line = utils.increment
        find_char = utils.find_forward_char
        get_line_text = utils.get_line
    end
    local text = get_line_text(line)

    repeat
        index, bracket = find_char(text, chars, col)
        if index then
            col = index
            index = index - 1

            ok, to_skip = pcall(skip, line, index)
            if not ok then return end

            if not to_skip then
                if bracket == same_bracket then
                    count = count + 1
                else
                    if count == 0 then
                        if stop(line, index) then return end
                        return line, index
                    else
                        count = count - 1
                    end
                end
            end
        else
            col = nil
            line = next_line(line)
            text = get_line_text(line)
        end
    until not text or stop(line, col)
end

-- Returns matched bracket position
-- @param matchpair table
-- @param line number line of `bracket`
-- @param col number column of `bracket`
-- @param stopline function
-- @return (number, number) or nil
function M.match_pos(matchpair, line, col, stopline)
    local stop
    local skip
    ts.highlighter = ts.get_highlighter()

    if ts.highlighter then
        local node = ts.get_skip_node(line, col)
        -- FiXME: this if condition only to fix annotying bug when treesitter isn't updated
        if node and not ts.is_node_comment(node) then
            if not ts.is_in_node_range(node, line, col + 1) then
                node = false
            end
        end

        if node then  -- inside string or comment
            stop = ts.limit_by_node(node, matchpair.backward)
        else
            ts.root = ts.get_tree_root()
            local parent = ts.node_at(line, col):parent()
            skip = function(l, c)
                return ts.in_ts_skip_region(l, c, parent)
            end
            stop = stopline or limit_by_line(line, matchpair.backward)
        end
    else  -- try built-in syntax to skip highlighting in strings and comments
        skip = syntax.skip_by_region(line, col)
        stop = stopline or limit_by_line(line, matchpair.backward)
    end

    return M.pair(matchpair, line, col, skip, stop)
end

return M
