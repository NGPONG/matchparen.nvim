" Used as argument for `searchpairpos()`, because it is not
" possible to use lua function reference in it
function! matchparen#skip() abort
    return luaeval("require'matchparen.syntax'.in_syntax_skip_groups()")
endfunction
