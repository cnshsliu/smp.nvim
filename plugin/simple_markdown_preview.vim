if exists('g:loaded_simple_markdown_preview')
    finish
endif
let g:loaded_simple_markdown_preview = 1

" Exposes the plugin's functions for use as commands in Neovim.
command! -nargs=0 SMPStart lua require("simple_markdown_preview").start()
command! -nargs=0 SMPPreview lua require("simple_markdown_preview").preview()
command! -nargs=0 SMPStop lua require("simple_markdown_preview").stop()
command! -nargs=0 SMPWikiVisual lua require("simple_markdown_preview").wrapwiki_visual()
command! -nargs=0 SMPWikiWord lua require("simple_markdown_preview").wrapwiki_word()
command! -nargs=0 SMPWikiLine lua require("simple_markdown_preview").wrapwiki_line()
command! -nargs=0 SMPPasteUrl lua require("simple_markdown_preview").paste_url()
command! -nargs=0 SMPPasteWikiWord lua require("simple_markdown_preview").paste_wiki_word()
