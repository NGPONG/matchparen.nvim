return {
    on_startup = true,
    timeout = 150,
    timeout_insert = 50,
    hl_group = 'MatchParen',
    augroup_name = 'matchparen',

    -- Neovim builtin syntax names to limit search only for this blocks
    -- Not sure if we really need all of this just copied from matchparen plugin itself
    -- Here is the comment from Bram about this syntax names
    -- "We match 'escape' for special items, such as lispEscapeSpecial, and
    --  match "symbol" for lispBarSymbol."
    syntax_skip_groups = {
        'string',
        'comment',
        'character',
        'singlequoute',
        'escape',
        'symbol',
    },

    -- TreeSitter names to limit search only in this blocks
    ts_skip_groups = {
        'string',
        'comment',
        'quoted_attribute',
    }
}
