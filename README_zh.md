# 简单的 Markdown 预览，大纲和增量搜索器

一个轻量级，易于使用的 Markdown[预览](#features)和[大纲](#markdown-book)和[增量搜索](#search-by-tag) NeoVim 插件，可以实时更新
和功能丰富，充分释放您的 Markdown 想象力。

是的，我们预览，列出大纲和增量搜索 Markdown, 以及更多方便使用 Neovim 进行 Markdown 编辑的工具
以及使用 Markdown 格式来维护你的全部笔记. 我们把 Neovim 和浏览器结合起来, 实现双向互通.

这些功能统一在一个插件中:"cnshsliu/smp.nvim”，

由 Markdown 爱好者为 Markdown 爱好者。如果你也喜欢这个插件，给我钉一个星星或[请我喝杯咖啡](https://buymeacoffee.com/liukehong)。

## 最近更新 📣:

2023-04-19 更新

我们现在支持通过用幻灯片方式播放你的 Markdown 文件。
具体怎样使用 Markdown 编辑幻灯片，请参考[Remark](https://github.com/remarkjs)

输入 `:Smp<cr>` 呼出命令面板，然后选择"remark slideshow" 来展示当前 Markdown 为幻灯片

2023-04-18 更新:

1.  在一个 Wiki word 上输入 Control-Enter， 将打开这个 Markdown 笔记。
2.  功能面板中提供切换是否自动预览的功能
3.  在开始预览时，保持窗口聚焦在 NeoVIM 编辑器中，不会切换到浏览器，大大方便编辑效率

😀 在浏览器中显示笔记中的标签, 链接 和 后向链接. 如果不需要这些功能,可以在 setup 中设置:

```
show_navigation_panel = false,
show_navigation_content = false,
```

浏览器中直接显示文中标签, 链接, 后向链接, 以及笔记的大纲, 你可以在浏览器中直接导航到你想要的笔记.

😀 请更新浏览器插件. 所提供的 Chrome/Edge 浏览器插增加了以下功能:

1. 一个 MD 自动只保留一个预览页;
2. 当在 NeoVim 中切换编辑笔记时, 浏览器自动跟着切换预览页
3. 请把这里的三个文件保存到本地, 按照 Chrome/Edge 插件的安装说明安装到浏览器中.
   [浏览器插件文件](https://github.com/cnshsliu/smp.nvim/tree/main/extension)

😀 **很兴奋地为您推荐有一个新功能: "在浏览器中查看笔记预览时, 向 NeoVim 发送指令,打开打开预览的笔记".
使用场景可能是这样的: 在 Neovim 中编辑一个笔记, 然后在浏览器中预览它, 此时,我们可能会点击
预览页中的某个链接, 此时, 浏览器会打开这个链接, 被显示的笔记如果需要修改, 我们只
需要点预览页中的"Edit"按钮, Neovim 就把这个文件加载起来, 供您修改.**

此功能将大大提升我们的笔记编辑体验, 请您马上试一试

😀 [目录功能](#toc-support) 两种形式:

1. 在笔记中固定位置直接生成目录, 所生成的目录成为笔记文字内容的一部分;
2. 在笔记的任意位置放置{toc}, 而{toc}在预览页中将显示为当前笔记的目录结构

😀 [命令面板](#command-panel) 显示本插件的所有命令, 选择后即被执行: `:Smp<cr>`

😀 [截断长文字行](#break-long-line), 常用的 Markdown 语法检查器,
会要求单行文字不超过 80 个字符, 但是在实际使用中, 有时候我们需要在一行中
写很长的文字, 如果我们的文字是从其它地方粘贴过来, 长文字的情况会更容易
发生, 使用自动文字截断功能, 即可保持每行的文字不超过你设置的宽度.

😀 [自动转换粘贴的 URL 地址为 MD 链接格式](#convert-url-into-link-automatically),
使用场景是: 浏览网页, 拷贝网页地址到 NeoVim, 或者将网页地址拖拽到 NeoVim,
此时, 本插件会自动取得网页的标题, 并将 URL 转换为 MD 链接格式: `[网页标题](网页地址)`
我本人经常使用这个功能, 保存微信公众号文章.

😀 [转换本地文件路径名为连接](#drop-files), 该功能非常有用,我们可以使用它来管理本地文件, 或者从 IM 群中拖拽文件到 Markdown 中.
例如, 在微信聊天中的文件, 你可以从微信中, 拖动文件到 NeoVim 中, 本插件会自动将文件转换成一个链接.

😀 [自动切换浏览器当前预览页](#switch-browser-tab-automatically)

我们可以在 NeoVim 中同时打开多个 Markdown 笔记文件, 当我们在 NeoVim 中切换
当前编辑笔记时, 浏览器自动切换到当前所编辑笔记的预览页面

🎉🎉🎉 **[以上是最近的更新, 全部功能, 成为你的 Markdown 笔记利器, 请点这里看下面 ](#all-features)**

## 使用 Packer 安装

请将下面的代码, 放到你的 `init.lua` 中:

```lua
use {
  'cnshsliu/smp.nvim',
  -- 你需要保障你的系统中有 nodejs 和 npm
  run="cd server && npm install",
  requires = {
    "nvim-telescope/telescope.nvim",
    "MunifTanjim/nui.nvim",
  },

}

require("smp").setup({
    --你的笔记文件夹
    home = vim.fn.expand("~/zettelkasten"),
    -- 对使用Telekasten的用户, 保留下面一行
    -- 如果你不用Telekasten, 留着这一行也没有问题
    templates = home .. "/" .. "templates",
    -- 自定义的 markdown css, 如果没有定义或者文件不存在, 将使用默认的 css
    smp_markdown_css = "~/.config/smp/my_markdown.css",
    -- Markdown片段所在目录, 如果没有定义或者目录不存在,
    -- {snippet}将不会被扩展
    smp_snippets_folder = "~/.config/smp/snippets",
    -- 如果单行笔记文字指向一个本地文件
    -- 本插件自动拷贝这个文件放到笔记目录下的assets子目录中
    copy_file_into_assets = true,
    -- 在预览页面中显示, 当前编辑行的指示
    show_indicator = true,
    -- Neovim中加载笔记时,自动在浏览器中打开预览
    auto_preview = true,
    -- 在预览页面中,显示结构导航面板
    show_navigation_panel = true,
    -- 在预览页面中,自动插入结构导航内容
    -- 你也可以在设置本参数为false后,
    -- 在笔记中使用{tags} {links}, {backlinks}来显示结构导航内容
    show_navigation_content = true,
})
```

## 屏幕截图

[](https://user-images.githubusercontent.com/2124836/226198265-b40ac0e7-6aea-42ff-9202-438edf7b54c6.mp4)

<img width="1192" alt="image" src="https://user-images.githubusercontent.com/2124836/227623987-31653e82-4304-4307-adea-6183d726a588.png">

## 全部功能

本插件提供以下丰富功能, 大大提升使用 Neovim 来编辑 Markdown 文件, 或者用于笔记管理:

- [Markdown 预览](#previewer)

  - [命令面板](#command-panel) `:Smp<cr>` 呼出
  - [支持 Wiki 格式链接](#wiki-link-support)
    在 Markdown 笔记中的
    ```
    [[另一个笔记名]]
    ```
    会被自动转换为链接显示在预览页中, 点击链接可以跳转到另一个笔记
  - [预览页面中图片正常显示, 包括本地图片](#images)
  - [在 Telekasten 笔记间跳转](#telekasten-note) 本质上跟前面的 Wiki 链接一样, 只是使用了 Telekasten 的笔记名
  - [预览页中显示当前正在编辑的行](#cursor-following)
  - [代码块中的当前行一样在预览中被高亮](#codes-line-highlight)
  - [配置示例](#example-configuration)
  - [支持 PlantUML](#plantuml)
  - [支持 Latex](#latex)
  - [支持 Mermaid](#mermaid)
  - [支持参考链接](#references-link)
  - [支持自定义 Markdown CSS](#custom-markdown-css)
  - [支持使用 Markdown 片段扩展](#template-snippet)
    - 例如,你可以为你所有的 Markdown 文件, 添加{header} 和 {footer}, 从而保持统一的头部和尾部
  - [本地文件拖拽到 NeoVim, 自动转换为连接](#drop-files) 🎉
  - [自动切换浏览器预览页到当前编辑笔记](#switch-browser-tab-automatically)
  - [自动转换拖入的 URL 为链接, 并自动尝试添加网页标题](#convert-url-into-link-automatically)
  - [支持目录](#toc-support)
  - [自动打断长文字](#break-long-line-into-multiple-line)
  - [在连续多行之间插入空行](#insert-blank-lines-between-lines)

- [Markdown 大纲 (the book)](#markdown-book)
  - [在独立窗口中显示 Markdown 大纲](#markdown-book) `:SmpBook`
    [搜索](#search-by-tag)
    - [递进式, 按标签搜索](#search-by-tag) `:SmpSearchTag`
    - [递进式, 按内容文字搜索](#search-by-text) `:SmpSearchText`
    - [搜索条件保存及调用](#saved-search)
- [代办事项同步](#others)
  - [在 Markdown 代办和 MacOS Reminder 应用之间同步](#sync-todos) 🎉 从而, 我们可以
    在 Markdown 中所编辑的代办事项, 可以跟你的 iPhone 和 MacBook 上的 Reminder 应用同步
- [安装前需求](#requirements)
- [安装](#installation)
- [开始使用](#getting-started)
- [开始预览](#preview-markdown)
- [全部命令](#all-commands)
- [需要你的帮助](#ask-for-your-help)
- [其它](#others)

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
