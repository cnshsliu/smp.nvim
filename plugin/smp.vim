if exists('g:loaded_simple_markdown_preview')
    finish
endif
let g:loaded_simple_markdown_preview = 1

" Exposes the plugin's functions for use as commands in Neovim.
command! -nargs=0 SmpStart lua require("smp").start()
command! -nargs=0 SmpPreview lua require("smp").preview()
command! -nargs=0 SmpStop lua require("smp").stop()
command! -nargs=0 SmpWikiVisual lua require("smp").wrapwiki_visual()
command! -nargs=0 SmpWikiWord lua require("smp").wrapwiki_word()
command! -nargs=0 SmpWikiLine lua require("smp").wrapwiki_line()
command! -nargs=0 SmpPasteUrl lua require("smp").paste_url()
command! -nargs=0 SmpPasteWikiWord lua require("smp").paste_wiki_word()
