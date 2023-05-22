if exists('g:loaded_simple_markdown_preview')
    finish
endif
let g:loaded_simple_markdown_preview = 1

function! s:smp_complete(arg,line,pos)
    let l:candidates = luaeval('require("smp").subcommands()')
  return join(l:candidates, "\n")
endfunction
" Exposes the plugin's functions for use as commands in Neovim.
" command! -nargs=0 Smp lua require("smp").panel()
command! -nargs=? -range -complete=custom,s:smp_complete Smp lua require('smp').panel(<f-args>)
