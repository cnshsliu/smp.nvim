# Simple Markdown Previewer, Outliner and Incremental Searcher

A lightweight, easy-to-use Markdown [preview](#features) and [outline](#markdown-book) and [incrementally search](#search-by-tag) plugin for NeoVim, which live updates
and feature-rich, to fully unleash your Markdown imagination.

Yes, we [preview](#features), [outline](#markdown-book) and [incrementally search](#search-by-tag) Markdown in one plugin: "cnshsliu/smp.nvim", by Markdown lover for Markdown lover. If you love this plugin also, pin me a star or [buy me a coffee](https://buymeacoffee.com/liukehong).

1️⃣ [Quick Start](#quick-start-with-packer) 2️⃣ [Screenshots](#screenshots) 3️⃣ [All Features](#all-features)

## Latest Update:

😀😀😀 [Turn URL into markdown link automatically](#convert-url-into-link-automatically), scenario: visiting a site, copy & paste it's URL from browser to Neovim, or drag a link to NeoVim, the URL will be converted into a link: `[Web Page Title](web page url)` automatically.

😀😀😀 [Switch browser tab automatically when we edit multiple Markdowns](#switch-browser-tab-automatically)

You may be editing several Markdown files in NeoVim at the same time,
when you switch from one file to another,
you'd like to let browser to switch previewing tab to your current editing Markdown.

😀😀😀 [Make a Markdown link on Drag and dropping file from Finder](#drop-files)

[See more exiting features for Markdown lover...](#all-features)

## Quick start with Packer

```lua
use {
  'cnshsliu/smp.nvim',
  run="cd server && npm install",   -- yes, we should have node & npm installed.
  requires = {
    "nvim-telescope/telescope.nvim",
    "MunifTanjim/nui.nvim",
  },

}

require("smp").setup({
    --where are your MDs
    home = vim.fn.expand("~/zettelkasten"),
    -- for Telekasten user, don't use Telekasten? keep this line, no harm
    templates = home .. "/" .. "templates",
    -- your custom markdown css, if not defined or not exist,
    -- will use the default css
    smp_markdown_css = "~/.config/smp/my_markdown.css",
    -- your markdown snippets, if not defined or not exist,
    -- snippets like {snippet_1} will keep it's as-is form.
    smp_snippets_folder = "~/.config/smp/snippets",
    -- copy single line filepath into 'home/assets' folder
    -- default is true
    copy_file_into_assets = true,
})
```

## Screenshots

https://user-images.githubusercontent.com/2124836/226198265-b40ac0e7-6aea-42ff-9202-438edf7b54c6.mp4

<img width="1192" alt="image" src="https://user-images.githubusercontent.com/2124836/227623987-31653e82-4304-4307-adea-6183d726a588.png">

## All Features

Besides the basic features of markdown preview, this plugin has the following:

- [Previewer](#previewer)

  - [Clickable wiki links](#wiki-link-support)
  - [Show images on web and local disk](#images)
  - [Clickable Telekasten note (zk etc.)](#telekasten-note)
  - [A red block indicator points to current editting line](#cursor-following)
  - [Highlight current line in code blocks](#codes-line-highlight)
  - [PlantUML](#plantuml)
  - [Latex](#latex)
  - [Mermaid](#mermaid)
  - [References link](#references-link)
  - [Custom Markdown CSS support](#custom-markdown-css)
  - [Markdown Template Snippet](#template-snippet)
    - A simple requirement scenario is to have the same {header} and {footer} for all your Markdown.
  - Smooth scrolling to current line, sync between NeoVim and browser
  - [Drop files from Finder into Neovim, and convert it to link automatically. ](#drop-files) 🎉
  - [Switch browser tab automatically](#switch-browser-tab-automatically) when you switch among multiple Markdown files

- [Outliner (the book)](#markdown-book)
  - [Show Book in a standalone buffer](#markdown-book) `:SmpBook`
- [Searcher](#search-by-tag)
  - [Search by tags incrementally](#search-by-tag) `:SmpSearchTag`
  - [Search by text incrementally](#search-by-text) `:SmpSearchText`
  - [Saved search](#saved-search)
- [Others](#others)
  - [Sync Todo with MacOS Reminder Application](#sync-todos) 🎉 so we can  
    sync todo lists among iPhone Reminder, Mac Book Reminder and Neovim
- On the roads:
  - Fully customizable
  - One key (command) in NeoVim to start print in browser, there, you could  
    choose to send to a physical printer or print to PDF.
  - and more... (fully unleash your imagination, you ask, I implement )
- [Requirements](#requirements)
- [Getting started](#getting-started)
  - [Installation](#installation)
  - [Preview Markdown](#preview-markdown)
  - [Key mappings](#mappings)
- [Need your helps](#ask-for-your-help)
- [Others](#others)

## Previewer

Preview your markdown on-the-fly.

### Wiki Link Support

Clickable Wiki link or telekasten link in double bracket form: \[\[WIKI_WORD]]
If the target local MD file does not exist, show it in warning color.

![image](https://user-images.githubusercontent.com/2124836/226204554-4d0bd902-553f-4742-987d-6c1aaf3427a8.png)

### Images

Show images both from web URL and local disk. for example:

```markdown
![img1](https://someserver-URL/image.jpg)
![img1](images/image.jpg)
```

The first image is loaded from it's web URL, the second is loaded from local disk.

### Telekasten Note

Same as Wiki links actually, a Telekasten Note named "Work" is written as `[[Work]]`,
and there is a file named `Work.md` accordingly on the disk.
If this file does not exist, it will be shown in warning color, or else, you can
click it to jump to the note directly in the preview.

### Cursor following

A red block indicator always locates at the current line you are editting

https://user-images.githubusercontent.com/2124836/226205371-b9710ad5-5480-4fc3-ba80-fef4549c9bce.mp4

If you don't like it, just disable it by including

```lua
    show_indicator = false,
```

in your setup()

Or, `SmpIndicator 0` to disable, `SmpIndicator 1` to enable,
and `SmpIndicator -1` to use "show_indicator" value defined in setup()

### Codes line highlight

If you move cursor into a line within a code block, that line will also be highlighted.
![image](https://user-images.githubusercontent.com/2124836/226204837-fe3016c9-1b8b-476e-921a-f075764d27b3.png)

### PlantUML

![image](https://user-images.githubusercontent.com/2124836/226204621-2c3079b4-cf73-4da6-ad0e-be2b30efb819.png)

### Latex

![image](https://user-images.githubusercontent.com/2124836/226216829-805a95e4-9dfc-47ed-985f-9da6c24b0a91.png)

### Mermaid

![image](https://user-images.githubusercontent.com/2124836/226700147-e3a05791-b257-41a5-bb9e-bb7b13dcf11b.png)

### References link

For example, if you have following Markdown text,
the `[Marked]` and `[Markdown]` will be displayed as
linkes to `https://github.com/markedjs/marked/` and `http://daringfireball.net/projects/markdown/`

```markdown
[Marked] lets you convert [Markdown] into HTML. Markdown
is a simple text format whose goal is to be very easy to read and write,
even when not converted to HTML. This demo page will let you type
anything you like and see how it gets converted. Live. No more waiting around.

[Marked]: https://github.com/markedjs/marked/
[Markdown]: http://daringfireball.net/projects/markdown/
```

### Custom Markdown CSS

You may use your own markdown CSS file by define smp_markdown_css in setup()
, for example:

```lua
require("smp").setup({
	smp_markdown_css = "~/.config/smp/my_markdown.css",
})
```

If the file does not exist, it will fallback to the default CSS.

### Template Snippet

You can include a snippet (template) in your Markdown file,
each template is a file under your snippets folder.

snippets folder is defined by `smp_snippets_folder`, for example:

```lua
require("smp").setup({
	smp_snippets_folder = "~/.config/smp/snippets",
})

```

For exmaple, you may define snippets named "myHeader" and "myFooter",
you should accordingly have "myHeader.md" and "myFooter.md" files in
`smp_snippets_folder`, and then, you could include them in your
Markdown files with `{myHeader}` or `{myFooter}`.

{myHeader} will be replaced with the content of "myHeader.md" file,

{myFooter} will be replaced with the content of "myFooter.md" file,

Tempalte can be used in a cascaded way, that means, you can include snippets
in another snippets.

And, please make sure:

1. Keep one and only {snippet} on single line, keep only one snippet on one line,
2. **Must avoid having looped includes!!!**
3. If the "snippet.md" file does not exist, no expansion will happen and the  
   text will be kept in {snippet} form

In browser previewing, snippets will be automatically displayed
as their contents,
however, if you want to expand them in place right within your Markdown
file, that means, to repalce {snippets} with it's content, you
could:

1. replace one by one:  
    While you are on a line of {snippet}
   call `:SmpExpandSnippet` to expand it.
2. replace all snippets in current buffer  
   call `:SmpExpandAllSnippets` to expand them all.

Simple Markdown Preview does not provide default keymappings for these
two functions, please define by yourself as needed.

### Drop Files

You may drop a file from MacOS Finder into NeoVim,
the full file pathname will be inserted into
your Markdown. SMP could convert this file into
a Markdown link automatically after dropping.

For example, you select a file named "abcd.jpg"
in your home folder in Finder,
drop this file into NeoVim,
"/Users/your_user_name/abcd.jpg"
will be inserted into your Markdown file.

If "/Users/your_user_name/abcd.jpg" does exist
(If you drag and drop it from Finder,
it does exist, if you type this file path,
may not exist, SMP will check the existance anyway),
it will be converted into

```markdown
[abcd](/SMP_MD_HOME/assets/xxxxxxxxxxxx.jpg)
```

SMP_MD_HOME means the home folder you defined in [setup](#quick-start-with-packer),

The file "/Users/your_user_name/abcd.jpg"
will be copied to
"SMP_MD_HOME/assets/xxxxxxxxxxxxx.jpg"

This way, we keep all dropped file in 'assets' folder.

If you don't like this function, you could disable it by
set the following flag to false explicitly in your setup().

"copy_file_into_assets = false"

### Convert URL into Link Automatically

Keep a valid URL on a single line, it will be converted into a link automatically. the page title will also be extracted automatically for you.

### Switch browser tab automatically

Switch files in Neovim, browser will switch previewing tab automatically for you.

![FollowMd](https://user-images.githubusercontent.com/2124836/228006327-45db610e-543c-4335-a9f4-3ea914a80c7c.gif)

Just install a simple Edge/Chrome extension.
you need to install it manually currently.

[Download zip file](https://github.com/cnshsliu/smp.nvim/blob/main/extension/smp_nvim_companion.zip?raw=true), and install the extension manually to Edge or Chrome browser.

## Markdown Book

Outline markdown structures in a standalone buffer, list out all tags,
backlinks, and forward links. todos, and headers

`:SmpBook`

<img width="1192" alt="image" src="https://user-images.githubusercontent.com/2124836/227623987-31653e82-4304-4307-adea-6183d726a588.png">

Press on each item will bring you to there.

While you are on a markdown header entry, use '>>' to demote it, use '<<' to promote it.

press '?' in the book buffer to bring up help
<img width="1400" alt="image" src="https://user-images.githubusercontent.com/2124836/227632690-dd8d9fd1-bd10-405c-8af5-390d57d311dd.png">

### Search by tag

Search by multiple tags delimitered with space or ',', "-tagA" to exlude "tagA", ":short-name" to give it a name to save the query condition for later reuse.
<img width="1196" alt="image" src="https://user-images.githubusercontent.com/2124836/227624370-fef7b8e1-f64d-4cd7-8f6b-59c2d49bb668.png">

`:mysearch -tagA tagB tagC`

means you'd like to search all markdown fiels which have #tagB, #tagC, but not tagA. and save it as "mysearch". The order of these element does not matter.

### Search by text

Search by multiple text delimitered with space or ',',

`textA textB :mytextsearch -textC`

means you'd like to search all markdown fiels which contain textA, textB, but not textC. and save it as "mytextsearch". The order of these element does not matter.

### Saved Search

Use search syntax described above to save your query, next time, you could pick a saved search with Telescope picker,
and re-run it by hitting `<CR>`.

### Sync Todos

`:SmpSyncTodo` will sync your Markdown todos with MacOS Reminder application, since reminders are kept synchronized between iPhone and MacBook already, so you are now able to access your todos anywhere, anytime with either your iPhone, MacBook.

The synchronization is bidirectional.

## Requirements

1. NeoVim v0.6.0 or higher.

2. Node.js v14.0 or higher.

## Getting started

### Installation

Packer (packer.nvim)

```lua
use {
  'cnshsliu/smp.nvim',
  run="cd server && npm install"
}
```

I don't use other package manager than Packer, if you are familiar with them,
kindly update this README.

### Setup

```lua
require("smp").setup({
	-- home = require("telekasten").Cfg.home or vim.fn.expand("~/zettelkasten"),
	home = vim.fn.expand("~/zettelkasten"),
	templates = home .. "/" .. "templates",
	smp_markdown_css = "~/.config/smp/my_markdown.css",
	smp_snippets_folder = "~/.config/smp/snippets",
})
```

### Preview Markdown

Press

`:SmpPreview`

to start to preview the current buffer.

1. `:SmpPreview`: start service and preview the current buffer`
2. `:SmpStart`: start background service without open browser
3. `:SmpStop`: stop background service

Normally, you only use SmpPreview command, if service is not started,
it will start service first, then open browser for previewing, otherwise,
it will preview directly.

When you close NeoVim window, the background service will be shutdown
as well. you don't have to close it manually.

The background service is written with Node.js, that's why Node.js is
in the dependency list of this plugin.

### Mappings

```lua
    vim.keymap.set("n", "<leader>kt", ":lua require('smp').wrapwiki_visual()<CR>")
    vim.keymap.set("v", "<leader>kv", ":lua require('smp').wrapwiki_visual()<CR>")
    vim.keymap.set("n", "<leader>kw", ":lua require('smp').wrapwiki_word()<CR>")
    vim.keymap.set("n", "<leader>kl", ":lua require('smp').wrapwiki_line()<CR>")
    vim.keymap.set("n", "<leader>k1", "<cmd>SmpPasteUrl<CR>")
    vim.keymap.set("n", "<leader>k2", "<cmd>SmpPasteWikiWord<CR>")
```

Explains:

1. `<leader>kt`, `<leader>kv`: wrap the selected text as a wiki link
2. `<leader>kw`: wrap the word under cursor as a wiki link
3. `<leader>kl`: wrap the current line as a wiki link
4. `<leader>k1`: paste url string in system clipboard as a Markdown link
5. `<leader>k2`: paste text in system clipboard as a wiki link in double square brackets.

paste URL is specially useful when you are browsing and want to copy the
web page url from browser and insert it into your note.

## Contributing

Feel free to open issues or submit pull requests to contribute to this project.

## Ask for your help

Need your help, and welcome your contribution

- Test on different OSs, environments.
- Raise issues
- Submit PRs
- Give Suggestions

  Thanks a lot, together we make SMP nicer.

## Others

SMP uses port 3030, a configuration to enable other port
you choose has not been implemented at this moment,
3030 may cause confliction with your other program,
if this is your case and you find out that port configuration is
must-to-have for you, please raise an issue.
I will add it ASAP.

For note taking, suggest [Telekasten](https://github.com/renerocksai/telekasten.nvim)
I take notes with Telekasten everyday, and just found I need another Markdown
previewer, so I wrote this one,
I am with a Macbook Pro, and this plugin is tested on MacOS only,
If you find any bugs on other OSs, kindly raise an issue,
I will fix it ASAP. thanks a lot.
