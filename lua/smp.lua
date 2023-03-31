local Json = require("json")
local Path = require("plenary.path")
local bookutils = require("book.bookutils")
local todoutils = require("todo.todoutils")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local themes = require("telescope.themes")
local Keymap = require("nui.utils.keymap")

local vim = vim
local lastlines = { "unset" }
local fn_key_map = {}

local M = {}
M.server_started = false
local __insert_blank_line_after = -1

local tmpdir
M.snippet_pattern = "^%s*{(.-)}%s*$"

if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    tmpdir = os.getenv("TEMP")
else
    tmpdir = "/tmp"
end
local logFile = vim.fn.fnamemodify(tmpdir, ":p") .. "smp_client.log"
local _home = vim.fn.expand("~/zettelkasten")

local internal_log = function(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_file = assert(io.open(logFile, "a"))
    log_file:write(timestamp .. " - " .. message .. "\n")
    log_file:close()
end

local internal_clear_log = function()
    local file_to_clear = assert(io.open(logFile, "w"))
    file_to_clear:close()
end

internal_clear_log()
internal_log("\n")

local function defaultConfig(home)
    if home == nil then
        home = _home
    end

    local cfg = {
        home = home,
        extension = ".md",
        templates = home .. "/" .. "templates",
        book_use_emoji = true,
        copy_file_into_assets = true,
        show_indicator = true,
        break_long_line_at = 80,
    }
    M.Cfg = cfg
end

local function Setup(cfg)
    cfg = cfg or {}
    bookutils.setup(cfg)
    defaultConfig(cfg.home)
    for k, v in pairs(cfg) do
        M.Cfg[k] = v
    end
    todoutils.setup(M.Cfg)
end

local function _setup(cfg)
    Setup(cfg)
end
M.setup = _setup
M.setup({})

local function break_string(str, limit)
    -- Initialize an empty table to store the output strings
    local output = {}
    -- Initialize an empty string to store the current line
    local line = ""
    -- Initialize a variable to store the current line width
    local line_width = 0
    -- Loop through the UTF-8 byte sequences of the input string using a pattern
    for char in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        -- Get the display width of the current character
        local char_width = vim.fn.strdisplaywidth(char)
        if line_width + char_width > limit then
            table.insert(output, line)
            line = ""
            line_width = 0
        end
        -- Append the current character to the current line and update the line width
        line = line .. char
        line_width = line_width + char_width
    end
    -- If there is any remaining line, append it to the output table
    if line ~= "" then
        table.insert(output, line)
    end
    -- Return the output table
    return output
end

local __open_url = function(url)
    if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
        vim.fn.system(string.format("start '%s'", url))
    elseif vim.fn.has("unix") == 1 then
        if vim.fn.has("mac") == 1 then
            vim.fn.system(string.format("open '%s'", url))
        else
            vim.fn.system(string.format("xdg-open '%s'", url))
        end
    else
        print("Unsupported operating system.")
    end
end

local __post2 = function(host, port, endpoint, data)
    local url = string.format("http://%s:%d%s", host, port, endpoint)
    local suffix = ".json"
    local payloadFile = tmpdir .. "/tempfile" .. suffix
    local outfile = tmpdir .. "/tempfile.out"

    local file, err = io.open(payloadFile, "w")
    if not file then
        print("Error opening file: " .. err)
        return
    end
    file:write(Json.stringify(data))
    file:close()

    -- Use curl to make the POST request with the payload file
    local command = string.format(
        "curl -s -X POST -H 'Content-Type: application/json' -d '@%s' %s >%s 2>/dev/null",
        payloadFile,
        url,
        outfile
    )
    internal_log(command)
    os.execute(command)
    -- local success, status, code = os.execute(command)
    -- if not success then
    --     print("Error executing curl: " .. status)
    --     -- elseif code ~= 0 and code ~= "" then
    --     --     print(
    --     --         "Curl exited with non-zero status code: "
    --     --             .. vim.inspect(code or "")
    --     --             .. "command: "
    --     --             .. command
    --     --     )
    -- end

    -- local lua_cmd = string.format(
    --     "lua -e \"local json=require('json'); io.write(%s)\"",
    --     Json.stringify(data)
    -- )
    -- local curl_cmd = string.format(
    --     "curl -X POST -H 'Content-Type: application/json' -d @- %s",
    --     url
    -- )
    -- local pipe = io.popen(lua_cmd .. " | " .. curl_cmd, "r")
    -- local output = pipe:read("*all")
    -- pipe:close()
    -- local _, _, code = output:find("HTTP/%d%.%d (%d+)")
    -- local _, _, status = output:find("HTTP/%d%.%d %d+ ([^\r\n]+)")
    -- local _, _, body = output:find("\r\n\r\n(.*)")
    -- if code ~= 200 then
    --     print("Post ERROR", code, res_body, status, vim.inspect(headers))
    -- end
end

local __get_title = function(url, callback)
    __post2("127.0.0.1", 3030, "/urltitle", { url = url })
    local outfile = tmpdir .. "/tempfile.out"
    local file = io.open(outfile, "r")
    if file == nil then
        print("file is nil")
    else
        local content = file:read("*all")
        file:close()
        callback(content)
    end
end

local function compare_tables(t1, t2)
    if t1 == nil or t2 == nil then
        return false
    end
    -- Check if the lengths of both tables are the same
    if #t1 ~= #t2 then
        return false
    end

    -- Compare each element in the tables
    for i = 1, #t1 do
        if t1[i] ~= t2[i] then
            return false
        end
    end

    -- If all elements are the same, return true
    return true
end

local function create_limited_function(func, time_period)
    local timer = nil

    return function(arg)
        if timer then
            timer:stop()
        end

        timer = vim.loop.new_timer()
        timer:start(
            time_period,
            0,
            vim.schedule_wrap(function()
                func(arg)
                timer:stop()
            end)
        )
    end
end

local do_post_smp_config = function()
    local config = {
        cssfile = M.Cfg.smp_cssfile,
        snippets_folder = M.Cfg.smp_snippets_folder,
        home = M.Cfg.home,
        show_indicator = M.Cfg.show_indicator,
    }
    if config.cssfile then
        config.cssfile = vim.fn.expand(config.cssfile)
    end
    if config.snippets_folder then
        config.snippets_folder = vim.fn.expand(config.snippets_folder)
    end
    __post2("127.0.0.1", 3030, "/config", config)
end

local concat_file_path = function(folder, filename)
    -- Check if the folder path ends with a slash
    if folder:sub(-1) ~= "/" then
        folder = folder .. "/"
    end

    -- Join the folder path and filename together
    local full_path = vim.fn.join({ folder, filename }, "")

    return full_path
end

local function urlEncode(s)
    local function charToHex(c)
        return string.format("%%%02X", string.byte(c))
    end

    return s:gsub("([^%w %-%_%.%~])", charToHex):gsub(" ", "+")
end

local filePath = "C:\\Users\\Example\\Documents\\file.txt"
local escapedString = urlEncode(filePath)
print(escapedString) -- Output: C%3A%5CUsers%5CExample%5CDocuments%5Cfile.txt

local generate_short_uuid = function()
    local template = "xxxxxxxxxxxxx"
    local uuid = ""
    math.randomseed(os.time())
    math.random()
    math.random()
    math.random() -- To avoid predictable sequences
    for i = 1, #template do
        local c = template:sub(i, i)
        if c == "x" then
            uuid = uuid .. string.format("%x", math.random(0, 15))
        else
            uuid = uuid .. c
        end
    end
    return uuid
end

local get_file_suffix = function(filename)
    local suffix = string.match(filename, "%.([^.]+)$")
    return suffix
end

local trim = function(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end
local is_valid_url = function(url)
    local pattern = "^(https?://[%w-_%.%?%.:/%+=&%%]+#?[%w-_%.%?%.:/%+=&%%]*)$"
    return url:match(pattern) ~= nil
end

local function make_relative_to(A, B)
    local function split_path(path)
        local parts = {}
        for part in path:gmatch("[^/\\]+") do
            table.insert(parts, part)
        end
        return parts
    end

    local function join_path(parts)
        return table.concat(parts, "/")
    end

    local partsA = split_path(A)
    local partsB = split_path(B)
    local common_parts = {}

    while partsA[1] == partsB[1] do
        table.insert(common_parts, partsA[1])
        table.remove(partsA, 1)
        table.remove(partsB, 1)
    end

    for _ = 1, #partsA - 1 do
        table.insert(partsB, 1, "..")
    end

    return join_path(partsB)
end

local convert_line_to_wiki_link = function(line, current_file_path)
    local formatted_line = nil
    local linkType = ""

    line = trim(line)

    line = line:gsub("\\", "")

    if vim.fn.filereadable(line) == 1 then
        local file_path = vim.fn.fnamemodify(line, ":p")
        local file_base_name = vim.fn.fnamemodify(file_path, ":t")
        local suffix = get_file_suffix(file_base_name)
        local file_in_assets = "assets/"
            .. generate_short_uuid()
            .. "."
            .. suffix
        local new_file_path = concat_file_path(M.Cfg.home, file_in_assets)
        -- local display_path = "/SMP_MD_HOME/" .. file_in_assets
        local display_path = make_relative_to(current_file_path, new_file_path)
        local mkdirCmd = 'mkdir -p $(dirname "' .. new_file_path .. '")'
        os.execute(mkdirCmd)
        local cpCmd = 'cp "' .. file_path .. '" "' .. new_file_path .. '"'
        os.execute(cpCmd)
        formatted_line = string.format("[%s](%s)", file_base_name, display_path)
        linkType = "WIKI"
    elseif is_valid_url(line) then
        __get_title(line, function(title)
            formatted_line = string.format("[%s](%s)", title, line)
        end)
        linkType = "URL"
    end
    return formatted_line, linkType
end

local function get_toc()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local toc = {}
    for _, v in ipairs(lines) do
        if v:find("^#+") then
            local level = v:match("^#+")
            local title = v:match("^#+%s+(.*)")
            local anchor = title:lower():gsub("%s+", "-")
            local _, header_level = string.gsub(level, "#", "")
            table.insert(
                toc,
                string.format(
                    "%s- [%s](#%s)",
                    string.rep("  ", header_level - 1),
                    title,
                    anchor
                )
            )
        end
    end
    -- return table.concat(toc, "\n")
    return toc
end

M.insert_toc_here = function()
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_get_current_line()
    local toc = get_toc()
    table.insert(toc, 1, line)
    table.insert(toc, "")
    vim.api.nvim_buf_set_lines(0, line_nr - 1, line_nr, false, toc)
end

-- local enter_insert_mode_if_normal = function()
--     local mode = vim.api.nvim_get_mode().mode
--     if mode == "n" or mode == "no" then
--         vim.fn.feedkeys("i", "n")
--     end
-- end

M.breakIfLong = function(limit)
    limit = tonumber(limit) or tonumber(M.Cfg.break_long_line_at)
    limit = limit >= 1 and limit or 1
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_get_current_line()
    local line_width = vim.fn.strdisplaywidth(line)
    if line_width > limit then
        local segments = break_string(line, limit)
        vim.api.nvim_buf_set_lines(0, line_nr - 1, line_nr, false, segments)
        return #segments
    end
end
--

local do_post_data_update = function()
    __insert_blank_line_after = -1
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local pos = vim.api.nvim_win_get_cursor(0)
    local bufnr = vim.api.nvim_win_get_buf(0)
    local file_path = vim.api.nvim_buf_get_name(bufnr)
    local current_line_number = pos[1]
    local current_line_text = vim.api.nvim_buf_get_lines(
        0,
        current_line_number - 1,
        current_line_number,
        false
    )[1]

    --convert file path to link
    if M.Cfg.copy_file_into_assets then
        for index, aLine in ipairs(lines) do
            local formatted_line, _ =
                convert_line_to_wiki_link(aLine, file_path)
            if formatted_line ~= nil then
                __insert_blank_line_after = index
                lines[index] = formatted_line
                vim.api.nvim_buf_set_lines(
                    bufnr,
                    index - 1,
                    index,
                    false,
                    { formatted_line }
                )
                if index == current_line_number then
                    current_line_text = formatted_line
                end
            end
        end
    end

    if M.server_started == false then
        internal_log("Pls wait for server start")
        return
    end
    -- internal_log("file_path=" .. file_path)
    local fn = vim.fn.expand(file_path)
    -- internal_log("fn=" .. fn)
    local linesTobePosted
    local lastlines_key = string.format("buf_%d", bufnr)
    -- internal_log("Post data update")

    -- internal_log(string.format("\tCheck lines key: %s", lastlines_key))
    local same_content = compare_tables(lines, lastlines[lastlines_key])
    -- internal_log(
    --     "\t\tSame content "
    --         .. (same_content and "SameConent" or "NotSameContent")
    -- )
    if same_content then
        -- internal_log(" \t\t\tPost NO_CHANGE ")
        linesTobePosted = { "NO_CHANGE" }
    else
        internal_log(string.format("\tPost %d lines", #lines))
        linesTobePosted = lines
        lastlines[lastlines_key] = lines
    end

    if fn == nil then
        internal_log("WHYYYYYYYYYYY, fn is nil")
    end
    local fn_key = fn_key_map[fn]
    if fn_key == nil then
        -- fn_key = generate_short_uuid()
        fn_key = urlEncode(fn)
        if fn then
            fn_key_map[fn] = fn_key
        end
    end
    internal_log(string.format("Update fn:%s\tfn_key=%s", fn, fn_key))
    local payload = {
        lines = linesTobePosted,
        pos = pos,
        bufnr = bufnr,
        fn = fn,
        thisline = current_line_text,
        fn_key = fn_key,
    }
    -- print(string.format("%s...%s...%d", "Post", vim.inspect(pos), bufnr))
    if payload.fn then
        __post2("127.0.0.1", 3030, "/update", payload)
        if __insert_blank_line_after > 0 then
            vim.api.nvim_buf_set_lines(
                bufnr,
                __insert_blank_line_after,
                __insert_blank_line_after,
                false,
                { "" }
            )
            vim.api.nvim_win_set_cursor(0, { __insert_blank_line_after + 1, 0 })
            __insert_blank_line_after = -1
        end
    end
    -- internal_log("\tPosted")
end

local post_data_update = create_limited_function(do_post_data_update, 400)

M.get_matching_line_numbers = function(pattern)
    local matching_lines = {}
    local num_lines = vim.api.nvim_buf_line_count(0)

    for i = 1, num_lines do
        local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
        if line:match(pattern) then
            table.insert(matching_lines, i)
        end
    end

    return matching_lines
end

local lcl_get_next_snippet_matching_line = function(pattern, start_from)
    local num_lines = vim.api.nvim_buf_line_count(0)

    for i = start_from, num_lines do
        local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
        if line:match(pattern) then
            return i
        end
    end

    return -1
end

local function set_register(register, text)
    vim.api.nvim_set_var("temp_text", text)
    vim.api.nvim_command("let @" .. register .. " = g:temp_text")
    vim.api.nvim_del_var("temp_text")
end

local function paste_from_register(register, pOrP)
    vim.api.nvim_command('normal! "' .. register .. pOrP)
end

local local_do_expand_snippet = function(linenr, show_notfound_warning)
    local ret
    local line = vim.api.nvim_buf_get_lines(0, linenr - 1, linenr, false)[1]
    local match = string.match(line, M.snippet_pattern)
    if match then
        local snippet_name = string.gsub(match, "^%s*(.-)%s*$", "%1")
        local snippet_path = Path.new(vim.fn.expand(M.Cfg.smp_snippets_folder))
        local fullpath = snippet_path:joinpath(snippet_name .. ".md")
        local file = io.open(fullpath.filename, "r")
        if file then
            local contents = file:read("*all")
            file:close()
            set_register("z", contents)
            local isLastLine = false
            if linenr == vim.api.nvim_buf_line_count(0) then
                isLastLine = true
            end
            if isLastLine then
                vim.api.nvim_command("normal! dd")
                paste_from_register("z", "p")
            else
                vim.api.nvim_command("normal! dd")
                paste_from_register("z", "P")
            end
            ret = "expanded"
        else
            if show_notfound_warning then
                vim.api.nvim_buf_set_lines(
                    0,
                    linenr,
                    linenr,
                    true,
                    { "Snippet not found: " .. fullpath.filename }
                )
                vim.defer_fn(function()
                    vim.api.nvim_win_set_cursor(0, { linenr, 0 })
                    vim.api.nvim_command("normal! u")
                end, 2000)
            end
            ret = "snippet_not_found"
        end
    else
        ret = "not_match"
    end
    return ret
end

M.expand_snippet = function()
    local linenr = vim.fn.line(".")
    local_do_expand_snippet(linenr, true)
end

M.expand_all_snippets = function()
    local num_lines = vim.api.nvim_buf_line_count(0)

    local start_from = 1

    for _ = 1, num_lines do
        local next_line =
            lcl_get_next_snippet_matching_line(M.snippet_pattern, start_from)
        if next_line > 0 then
            internal_log(next_line)
            vim.api.nvim_win_set_cursor(0, { next_line, 0 })
            local_do_expand_snippet(next_line, false)
            start_from = next_line + 1
        else
            break
        end
        vim.cmd("sleep 100m")
    end
end

M.start = function(openBrowserAfterStart)
    openBrowserAfterStart = openBrowserAfterStart or false
    local info = debug.getinfo(1, "S")
    local path = info.source:sub(2) -- Remove the '@' character at the beginning
    local cwd = path:match("(.*[/\\])")
    local cmd = "node"
    local args = { "smp.js" }
    local working_directory = cwd .. "/server"
    -- local log_output_file = "smp_server.log"
    -- local log_handle = io.open(log_output_file, "w")
    local spawn_params = {
        command = cmd,
        args = args,
        cwd = working_directory, -- Set the current working directory
        stdio = { nil, vim.loop.new_pipe(false), vim.loop.new_pipe(false) },
        -- stdio = { nil, log_handle, log_handle },
        exit_cb = function(handle, exit_code, signal)
            -- if log_handle then
            --     log_handle:close()
            -- end
            print("Process exited with code:", exit_code, "and signal:", signal)
            handle:close()
        end,
    }
    internal_log("Start server NOW!!!")
    lastlines = { "unset" }

    local handle, pid = vim.loop.spawn(cmd, spawn_params)
    -- print("Background process started with PID:", pid)
    if handle then
        -- local bufnr = vim.api.nvim_win_get_buf(0)
        -- print(string.format("%s, %d", "create autocmd in buffer", bufnr))
        M.pid = pid
        M.server_started = true
        internal_log("\tStarted, create autocmd ")
        local smp_group =
            vim.api.nvim_create_augroup("smp_group", { clear = true })
        vim.api.nvim_create_autocmd(
            { "CursorHold", "CursorMoved", "CursorHoldI", "CursorMovedI" },
            {
                pattern = { "*.md" },
                group = smp_group,
                callback = post_data_update,
            }
        )
        vim.api.nvim_create_autocmd(
            { "VimLeavePre" },
            { group = smp_group, callback = M.cleanup }
        )
        local function afterStart()
            internal_log("After server spawn")
            local bufnr = vim.api.nvim_win_get_buf(0)
            local lastlines_key = string.format("buf_%d", bufnr)
            local file_path = vim.api.nvim_buf_get_name(bufnr)
            local fn = vim.fn.expand(file_path)
            lastlines[lastlines_key] = nil
            do_post_smp_config()
            do_post_data_update()
            -- open browser here
            local fn_key = fn_key_map[fn]
            internal_log(string.format("Got fn_key for %s, got %s", fn, fn_key))
            local function open_browser()
                internal_log("Open browser now")
                local preview_url = string.format(
                    "http://127.0.0.1:3030/preview?fn_key=%s",
                    fn_key
                )
                print(preview_url)
                __open_url(preview_url)
            end
            if openBrowserAfterStart then
                vim.defer_fn(open_browser, 300)
            end
        end
        vim.defer_fn(afterStart, 1000)
    else
        M.server_started = false
        internal_log("\tServer start failed")
    end
end

M.cleanup = function()
    __post2("127.0.0.1", 3030, "/stop", {})
    M.server_started = false
end

M.indicator = function(flag)
    __post2("127.0.0.1", 3030, "/indicator", { indicator = flag })
end
M.indicator_on = function()
    __post2("127.0.0.1", 3030, "/indicator", { indicator = 1 })
end
M.indicator_off = function()
    __post2("127.0.0.1", 3030, "/indicator", { indicator = 0 })
end
M.indicator_as_config = function()
    __post2("127.0.0.1", 3030, "/indicator", { indicator = -1 })
end

M.stop = function()
    __post2("127.0.0.1", 3030, "/stop", {})
    M.server_started = false
    pcall(vim.api.nvim_del_augroup_by_name, "smp_group")
end

M.preview = function()
    if M.server_started == false then
        M.start(true)
        return
    end
    local bufnr = vim.api.nvim_win_get_buf(0)
    local lastlines_key = string.format("buf_%d", bufnr)
    lastlines[lastlines_key] = nil
    post_data_update()
    -- open browser here
    local file_path = vim.api.nvim_buf_get_name(bufnr)
    local fn = vim.fn.expand(file_path)
    local fn_key = fn_key_map[fn]
    local function open_browser()
        __open_url(
            string.format("http://127.0.0.1:3030/preview?fn_key=%s", fn_key)
        )
    end
    vim.defer_fn(open_browser, 300)
end

M.wrapwiki_visual = function()
    local function wrap_visual_selection(prefix, suffix)
        local start_line, start_col =
            vim.fn.getpos("'<")[2], vim.fn.getpos("'<")[3]
        local end_line, end_col = vim.fn.getpos("'>")[2], vim.fn.getpos("'>")[3]

        -- -- Insert suffix after the selected text
        vim.api.nvim_buf_set_text(
            0,
            end_line - 1,
            end_col,
            end_line - 1,
            end_col,
            { suffix }
        )
        -- --
        -- --     -- Insert prefix before the selected text
        vim.api.nvim_buf_set_text(
            0,
            start_line - 1,
            start_col - 1,
            start_line - 1,
            start_col - 1,
            { prefix }
        )
    end
    wrap_visual_selection("[[", "]]")
end

M.wrapwiki_word = function()
    local function wrap_word_under_cursor(prefix, suffix)
        -- Search for the beginning of the word under the cursor
        vim.cmd("normal! b")

        -- Get the start position of the word
        local start_line, start_col =
            vim.fn.getpos(".")[2], vim.fn.getpos(".")[3]

        -- Search for the end of the word under the cursor
        vim.cmd("normal! e")

        -- Get the end position of the word
        local end_line, end_col = vim.fn.getpos(".")[2], vim.fn.getpos(".")[3]

        -- Insert suffix after the word
        vim.api.nvim_buf_set_text(
            0,
            end_line - 1,
            end_col,
            end_line - 1,
            end_col,
            { suffix }
        )

        -- Insert prefix before the word
        vim.api.nvim_buf_set_text(
            0,
            start_line - 1,
            start_col - 1,
            start_line - 1,
            start_col - 1,
            { prefix }
        )
    end
    wrap_word_under_cursor("[[", "]]")
end

M.wrapwiki_line = function()
    local function wrap_current_line(prefix, suffix)
        -- Get the current line number
        local line_num = vim.fn.line(".")

        -- Get the entire line content
        local line_content =
            vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]

        -- Create the new wrapped line content
        local wrapped_line = prefix .. line_content .. suffix

        -- Replace the current line with the wrapped content
        vim.api.nvim_buf_set_lines(
            0,
            line_num - 1,
            line_num,
            false,
            { wrapped_line }
        )
    end
    wrap_current_line("[[", "]]")
end

M.paste_url = function()
    -- local res = fetch_page_title()
    -- if res and res.url and res.title then
    --     local data = string.format("[%s](%s)", res.title, res.url)
    --     vim.api.nvim_put({ data }, "l", false, true)
    -- end
    local url = vim.fn.getreg("+")
    local data = string.format("[%s](%s)", "TITLE", url)
    vim.api.nvim_put({ data }, "l", false, true)
    -- vim.cmd("normal! k^fTciw")
    vim.fn.feedkeys("k^fTciw", "n")
end

M.paste_wiki_word = function()
    -- local res = fetch_page_title()
    -- if res and res.url and res.title then
    --     local data = string.format("[%s](%s)", res.title, res.url)
    --     vim.api.nvim_put({ data }, "l", false, true)
    -- end
    local word = vim.fn.getreg("+")
    local data = string.format("[[%s]]", word)
    vim.fn.setreg("*", data)
    vim.fn.feedkeys("p")
    local function delayed_operation()
        vim.fn.setreg("*", word)
    end

    local delay_ms = 200
    vim.defer_fn(delayed_operation, delay_ms)
end

local function validate_and_generate_header(line)
    local n, text, _ = line:match("^(%s*)- %[(.-)%]%((#.-)%)$")

    if not n then
        return nil
    end

    local space_count = #n
    local level = math.floor(space_count / 2)

    if level * 2 == space_count then
        local header = string.rep("#", level + 1) .. " " .. text
        return level, header
    else
        return nil
    end
end

local function move_cursor_to_header(header)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    for i, line in ipairs(lines) do
        if line == header then
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            break
        end
    end
end

local function pressControlReturn()
    local cursor_position = vim.api.nvim_win_get_cursor(0)
    local line_nr, col = cursor_position[1], cursor_position[2] -- Convert to 0-indexed position

    local line = vim.api.nvim_get_current_line()
    local _, header = validate_and_generate_header(line)
    if header then
        vim.api.nvim_buf_set_mark(0, "t", line_nr, col, {})
        move_cursor_to_header(header)
    end
end

local function get_visual_selection_range()
    -- Check if visual mode is active
    return vim.fn.line("v") - 1, vim.fn.line(".")
end

local function insert_empty_lines_between_nonempty_lines()
    local buf = vim.api.nvim_get_current_buf()
    local start_line, end_line

    if
        vim.fn.mode() == "v"
        or vim.fn.mode() == "V"
        or vim.fn.mode() == "<C-v>"
    then
        start_line, end_line = get_visual_selection_range()
        vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
            "n",
            false
        )
    else
        start_line, end_line = 0, -1
    end

    local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
    local new_lines = {}
    local last_line_empty = false

    for i, line in ipairs(lines) do
        table.insert(new_lines, line)

        if line ~= "" then
            last_line_empty = false
            if i < #lines and lines[i + 1] ~= "" then
                table.insert(new_lines, "")
            end
        else
            if not last_line_empty then
                last_line_empty = true
            end
        end
    end

    vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, new_lines)
end

-- Call the function

M.insert_blank_line = function()
    insert_empty_lines_between_nonempty_lines()
end

local commands = function()
    return {
        { "preview", "preview", M.preview },
        { "show book", "show_book", M.book },
        { "sync todos with Mac Reminder", "sync_todos", M.synctodo },
        { "expand snippet", "expand_snippet", M.expand_snippet },
        { "expand all snippets", "expand_all_snippets", M.expand_all_snippets },
        { "break line", "break_line", M.breakIfLong },
        { "insert blank line", "insert_blank_line", M.insert_blank_line },
        { "show book of this", "show_book_of_this", M.bookthis },
        { "search md by content", "search_by_content", M.search_text },
        { "search md by tag", "search_by_tag", M.search_tag },
        { "insert toc here", "insert_toc_here", M.insert_toc_here },
        { "indicator on", "indicator_on", M.indicator_on },
        { "indicator off", "indicator_off", M.indicator_off },
        { "indicator as config", "indicator_as_config", M.indicator_as_config },
        { "wrap selected as wiki", "wrap_wiki_visal", M.wrapwiki_visual },
        { "wrap word as wiki", "wrap_wiki_word", M.wrapwiki_word },
        { "wrap line as wiki", "wrap_wiki_line", M.wrapwiki_line },
        { "paste url", "paste_url", M.paste_url },
        { "paste wiki word", "paste_wiki_word", M.paste_wiki_word },
        {
            "goto header from this TOC entry",
            "goto_header_from_toc_entry",
            M.gotoHeaderFromTocEntry,
        },
        { "start", "start_server", M.start },
        { "stop", "stop_server", M.stop },
    }
end

M.command = function(subcommand)
    local show = function(opts)
        opts = opts or {}
        pickers
            .new(opts, {
                prompt_title = "Command palette",
                finder = finders.new_table({
                    results = commands(),
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = entry[1],
                            ordinal = entry[2],
                        }
                    end,
                }),
                sorter = conf.generic_sorter(opts),
                attach_mappings = function(prompt_bufnr, _)
                    actions.select_default:replace(function()
                        -- important: actions.close(bufnr) is not enough
                        -- it resulted in: preview_img NOT receiving the prompt as default text
                        -- apparently it has sth to do with keeping insert mode
                        actions.close(prompt_bufnr)

                        local selection =
                            action_state.get_selected_entry().value[3]
                        selection()
                    end)
                    return true
                end,
            })
            :find()
    end

    if subcommand then
        -- print("trying subcommand " .. "`" .. subcommand .. "`")
        for _, entry in pairs(commands()) do
            if entry[2] == subcommand then
                local selection = entry[3]
                selection()
                return
            end
        end
        print("No such subcommand: `" .. subcommand .. "`")
    else
        local theme

        if M.Cfg.command_palette_theme == "ivy" then
            theme = themes.get_ivy()
        else
            theme = themes.get_dropdown({
                layout_config = { prompt_position = "top" },
            })
        end
        show(theme)
    end
end

M.panel = M.command

M.book = function()
    bookutils.BookShow()
end
M.bookthis = function()
    bookutils.BookThis()
end

M.search_text = function()
    bookutils.BookSearchText()
end

M.search_tag = function()
    bookutils.BookSearchTag()
end

M.synctodo = function()
    todoutils.synctodo()
end

M.gotoHeaderFromTocEntry = function()
    pressControlReturn()
end

Keymap.set(0, "n", "<C-CR>", function()
    pressControlReturn()
end)

Keymap.set(0, "v", "<C-CR>", function()
    insert_empty_lines_between_nonempty_lines()
end)

return M
