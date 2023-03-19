# Simple Markdown Preview Demo

A Neovim (lua) plugin for live-previewing Markdown files,
specially designed to work with wiki, telekasten etc.

https://user-images.githubusercontent.com/2124836/226198265-b40ac0e7-6aea-42ff-9202-438edf7b54c6.mp4

## Features

Besides the basic features of markdown preview, this plugin has the following:

1. [Clickable wiki links](#wiki-link-support)
2. [Show images on web and local disk](#images)
3. [Clickable Telekasten note (zk etc.)](#telekasten-note)
4. [A red block indicator points to current editting line](#cursor-following)
5. [Highlight current line in code blocks](#codes-line-highlight)
6. [Support PlantUML](#plantuml)
7. [Support references link](#references-link)
8. [Custom Markdown CSS support](#custom-markdown-css)
9. Smooth scrolling to current line, sync between Neovim and browser

## Wiki Link Support

Clickable Wiki link or telekasten link in double bracket form: \[\[WIKI_WORD]]
If the target local MD file does not exist, show it in warning color.

![image](https://user-images.githubusercontent.com/2124836/226204554-4d0bd902-553f-4742-987d-6c1aaf3427a8.png)

## Images

Show images both from web URL and local disk. for example:

```markdown
![img1](https://someserver-URL/image.jpg)
![img1](images/image.jpg)
```

The first image is loaded from it's web URL, the second is loaded from local disk.

## Telekasten Note

Same as Wiki links actually, a Telekasten Note named "Work" is written as `[[Work]]`,
and there is a file named `Work.md` accordingly on the disk.
If this file does not exist, it will be shown in warning color, or else, you can
click it to jump to the note directly in the preview.

## Cursor following

A red block indicator always locates at the current line you are editting

https://user-images.githubusercontent.com/2124836/226205371-b9710ad5-5480-4fc3-ba80-fef4549c9bce.mp4

## Codes line highlight

If you move cursor into a line within a code block, that line will also be highlighted.
![image](https://user-images.githubusercontent.com/2124836/226204837-fe3016c9-1b8b-476e-921a-f075764d27b3.png)

## PlantUML

![image](https://user-images.githubusercontent.com/2124836/226204621-2c3079b4-cf73-4da6-ad0e-be2b30efb819.png)

## Refernces link

For example, if you have following Markdown text, the `[Marked]` and `[Markdown]` will be displayed as
linkes to `https://github.com/markedjs/marked/` and `http://daringfireball.net/projects/markdown/`

```
[Marked] lets you convert [Markdown] into HTML. Markdown
is a simple text format whose goal is to be very easy to read and write,
even when not converted to HTML. This demo page will let you type
anything you like and see how it gets converted. Live. No more waiting around.

[Marked]: https://github.com/markedjs/marked/
[Markdown]: http://daringfireball.net/projects/markdown/

```

## Custom Markdown CSS

You may use your own markdown css file by define a vim global variable named `smp_cssfile`, for example:

For LunarVim, use:

```lua
vim.g.smp_cssfile = '~/.config/nvim/my_markdown.css'
```

Normal Neovim:

```vim
let g:smp_cssfile = '~/.config/nvim/my_markdown.css'
```

## Requirements

1. Neovim v0.6.0 or higher.

2. Node.js v14.0 or higher.

BTW, For note taking, suggest [Telekasten](https://github.com/renerocksai/telekasten.nvim)

I take notes with Telekasten everyday, and just found I need another Markdown
previewer, so I wrote this one,
I am with a Macbook pro, and this plugin is tested on MacOS only,
If you find any bugs on other OSs, kindly post an issue,
I will fix it ASAP. thanks a lot.

## Getting started

### Installation

Packer.nvim

```lua
	{
		"cnshsliu/simple_markdown_preview.nvim",
		run = "cd server && npm install",
	},
```

I don't use other package manager, if you are familiar with them, kindly update this README.

### Usage

Press `:SMPPreview` to start to preview the current buffer.

### Other Mappings

```lua
    vim.keymap.set("n", "<leader>kt", ":lua require('simple_markdown_preview').wrapwiki_visual()<CR>")
    vim.keymap.set("v", "<leader>kv", ":lua require('simple_markdown_preview').wrapwiki_visual()<CR>")
    vim.keymap.set("n", "<leader>kw", ":lua require('simple_markdown_preview').wrapwiki_word()<CR>")
    vim.keymap.set("n", "<leader>kl", ":lua require('simple_markdown_preview').wrapwiki_line()<CR>")
    vim.keymap.set("n", "<leader>k1", "<cmd>SMPPasteUrl<CR>")
    vim.keymap.set("n", "<leader>k2", "<cmd>SMPPasteWikiWord<CR>")
```
