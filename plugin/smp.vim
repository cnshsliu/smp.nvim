if exists('g:loaded_simple_markdown_preview')
    finish
endif
let g:loaded_simple_markdown_preview = 1

" Exposes the plugin's functions for use as commands in Neovim.
command! -nargs=0 Smp lua require("smp").panel()
