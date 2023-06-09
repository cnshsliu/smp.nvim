# Simple Markdown Previewer, Outliner and Incremental Searcher

[中文说明](https://github.com/cnshsliu/smp.nvim/blob/main/README_zh.md)

A lightweight, easy-to-use Markdown [preview](#features) and [outline](#markdown-book) and [incrementally search](#search-by-tag) plugin for NeoVim, which live updates
and feature-rich, to fully unleash your Markdown imagination.

Yes, we [preview](#features), [outline](#markdown-book) and [incrementally search](#search-by-tag) Markdown in one plugin: "cnshsliu/smp.nvim", by Markdown lover for Markdown lover. If you love this plugin also, pin me a star or [buy me a coffee](https://buymeacoffee.com/liukehong).

1️⃣ [Quick Start](#quick-start-with-packer) 2️⃣ [Screenshots](#screenshots) 3️⃣ [All Features](#all-features)

## Latest Update 📣:

### 2023-04-19 updates:

Use your markdown as a slide deck. We support [Remark](https://github.com/remarkjs) now.

you can use `:Smp<cr>` to bring up command palette, then choose "remark slideshow" to preview your markdown as a slide deck.

### 2023-04-18 updates:

1.  press Control-Enter on a wiki under cussor, will open it;
2.  toggle auto preview on/off, see this command in command palette;
3.  on MacOS, previewing MD will not lose focus of current Neovim window;

### 2023-04-17 updates:

😀 Show Tags, links, backlinks in preview browser tab. Can disable by setting

```
show_navigation_panel = false,
show_navigation_content = false,
```

Tags, links, backlinks allow you navigate among MDs conveniently.

😀 Update browser extension: 1. keep only one preview tab for each MD; 22. Active preview tab for current MD; [update now](https://github.com/cnshsliu/smp.nvim/tree/main/extension), place three files into a folder and follow chrome/edge extension instruction to install it manually to Edge or Chrome browser.

😀 **Excited to let you know another new feature: "Edit back in Neovim", the scenario is: 1. edit one markdown FILE_A, 2. preview FILE_A. 3. in previewing browser, navigate to another markdown FILE_B, 4. click on "Edit in Neovim", 5, the FILE_B markdown is opend in Neovim. exremely improve my markdown editing experience, give it a try by yourself**

😀 [TOC](#toc-support) 1. genrated TOC right in MD; 2. include TOC with {toc}

😀 [Command Panel](#command-panel) with `:Smp<cr>`

😀 [Break long line](#break-long-line), break long line into multiple lines

😀 [Convert URL into markdown link automatically](#convert-url-into-link-automatically), scenario: visiting a site, copy & paste it's URL from browser to Neovim, or drag a link to NeoVim, the URL will be converted into a link: `[Web Page Title](web page url)` automatically.

😀 [Switch browser tab automatically when we edit multiple Markdowns](#switch-browser-tab-automatically)

You may be editing several Markdown files in NeoVim at the same time,
when you switch from one file to another,
you'd like to let browser to switch previewing tab to your current editing Markdown.

😀 [Make a Markdown link on Drag and dropping file from Finder](#drop-files), this one is very useful for me, I can use it to manage files on local disk, or.... drag files from IM group other people sent into Markdown.

🎉🎉🎉 **[See more exiting features for Markdown lover...](#all-features)**

Or, [take a look at what commands we have](#all-commands), you will have a quick glance of what this plugin can do:

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

[Error fetching title](https://user-images.githubusercontent.com/2124836/226198265-b40ac0e7-6aea-42ff-9202-438edf7b54c6.mp4)

<img width="1192" alt="image" src="https://user-images.githubusercontent.com/2124836/227623987-31653e82-4304-4307-adea-6183d726a588.png">

## All Features

Besides the basic features of markdown preview, this plugin has the following:

- [Previewer](#previewer)

  - [Command Panel](#command-panel) with `:Smp<cr>`
  - [Clickable wiki links](#wiki-link-support)
  - [Show images on web and local disk](#images)
  - [Clickable Telekasten note (zk etc.)](#telekasten-note)
  - [A red block indicator points to current editting line](#cursor-following)
  - [Example Setup](#example-configuration)
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
  - [Convert URL into markdown link automatically](#convert-url-into-link-automatically)
  - [TOC](#toc-support)
  - [Break long line into multiple lines](#break-long-line-into-multiple-line)
  - [Insert blank lines between lines](#insert-blank-lines-between-lines)

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
  - [All commands](#all-commands)
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

[Error fetching title](https://user-images.githubusercontent.com/2124836/226205371-b9710ad5-5480-4fc3-ba80-fef4549c9bce.mp4)

If you don't like it, just disable it by including

```lua
    show_indicator = false,
```

in your setup()

Or, `SmpIndicator 0` to disable, `SmpIndicator 1` to enable,
and `SmpIndicator -1` to use "show_indicator" value defined in setup()

### Example Configuration

```lua
    require("smp").setup({
        home = require("telekasten").Cfg.home or vim.fn.expand("~/zettelkasten"),
        templates = home .. "/" .. "templates",
        smp_markdown_css = "~/.config/smp/my_markdown.css",
        smp_snippets_folder = "~/.config/smp/snippets",
        copy_file_into_assets = true,
        show_indicator = true,
        auto_preview = true,
        show_navigation_panel = true,
        show_navigation_content = true,
    })
```

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

### Break long line into multiple line

`:SmpBreakLineIfLong` default break line length is 80, you can change it by:

```
require("smp").setup({
...
        break_long_line_at = 80,
...
})
```

`:SmpBreakLineIfLong 1`  
`:SmpBreakLineIfLong 40`

### Insert blank lines between lines

Select multiple lines, press `<C-CR>` to insert blank lines between lines.

Sometime, we may paste text from elsewhere into neovim,
and there is only 'carriage return' but no blank lines
between texts, in Markdown preview, all text will be
concatenated into one line, no paragraph, this is not what we want.

By inserting blank lines, we see paragraphs in preview.

### Switch browser tab automatically

Switch files in Neovim, browser will switch previewing tab automatically for you.

![FollowMd](https://user-images.githubusercontent.com/2124836/228006327-45db610e-543c-4335-a9f4-3ea914a80c7c.gif)

Just install a simple Edge/Chrome extension.
you need to install it manually currently.

[Three files](https://github.com/cnshsliu/smp.nvim/tree/main/extension)

Follow Chrome/Edge extension installation instruction and install the extension manually to Edge or Chrome browser.

### TOC support

We support TOC in two ways:

1. Generate TOC automatically, and insert it into your Markdown file.
   `:Smp<CR>` to bring up command panel, select "insert toc here"
   `<C-CR>` on a TOC item will jump to the corresponding header.
   press `'t` will jump back to TOC.
2. Expand `{toc}` at previewing stage
   Include `{toc}` in your Markdown file, and it will be expanded into TOC in previewing window

### Command Panel

`:Smp<cr>` will bring up all SMP commands, press enter on one of them to invoke corresponding command.

You may map `:Smp<cr>` to your favorite key in "init.lua", for example:

```lua
   vim.keymap.set("n", "<leader>m", "<cmd>Smp<CR>", { silent = true })
```

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

### All Commands

`require('smp').preview()`: "preview current markdown file"

`require('smp').book()`: "open the markdown book in a splitted window on right"

`require('smp').synctodo()`: "Sync all todos in Markdown to MacOS Reminder"

`require('smp').expand_snippet()`: "Expand current snippet in place"

`require('smp').expand_all_snippets()`: "Expand all snippets in place"

`require('smp').breakIfLong()`: "Break line length if it's too long for easier editting"

`require('smp').insert_blank_line()`: "Insert blank lines between multiple lines of text"

`require('smp').bookthis()`: "Show book of this markdown file"

`require('smp').search_text()`: "Incremental search all markdown files by content"

`require('smp').search_tag()`: "Incremental search all markdown files by tags"

`require('smp').insert_toc_here()`: "Insert TOC here"

`require('smp').indicator_on()`: "Show current line indicator in previewer"

`require('smp').indicator_off()`: "Don't show line indicator in previewer"

`require('smp').indicator_as_config()`: "Show line indicator in previewer as configured"

`require('smp').wrapwiki_visual()`: "Wrap selected text into a wiki link"

`require('smp').wrapwiki_word()`: "Wrap word under cursor into a wiki link"

`require('smp').wrapwiki_line()`: "Wrap current line into a wiki link"

`require('smp').paste_url()`: "Paste url from clipboard into a link"

`require('smp').paste_wiki_word()`: "Paste word from clipboard into a link"

`require('smp').open_file_in_this_line()`: "System open the linked file in this line"

`require('smp').locate_file_in_this_line()`: "System locate the linked file in this line"

`require('smp').gotoHeaderFromTocEntry()`: "Jump to header from TOC entry"

`require('smp').start()`: "Start background server"

`require('smp').stop()`: "Stop background server"

### Keymaps

`:Smp` will bring up a command palette with all these commands. You can also map them to your own keys.

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
