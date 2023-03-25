local Json = require("json")
local Path = require("plenary.path")
local bookutils = require("book.bookutils")
local todoutils = require("todo.todoutils")

local vim = vim
local lastlines = { "unset" }

local M = {}
M.server_started = false

local tmpdir
M.snippet_pattern = "^%s*{(.-)}%s*$"

if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    tmpdir = os.getenv("TEMP")
else
    tmpdir = "/tmp"
end
local logFile = vim.fn.fnamemodify(tmpdir, ":p") .. "smp_client.log"
local _home = vim.fn.expand("~/zettelkasten")

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
    }
    M.Cfg = cfg
end

M.open_url = function(url)
    if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
        vim.fn.system("start " .. url)
    elseif vim.fn.has("unix") == 1 then
        if vim.fn.has("mac") == 1 then
            vim.fn.system("open " .. url)
        else
            vim.fn.system("xdg-open " .. url)
        end
    else
        print("Unsupported operating system.")
    end
end

M.log = function(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_file = assert(io.open(logFile, "a"))
    log_file:write(timestamp .. " - " .. message .. "\n")
    log_file:close()
end

M.clear_log = function()
    local file_to_clear = assert(io.open(logFile, "w"))
    file_to_clear:close()
end

M.post2 = function(host, port, endpoint, data)
    local url = string.format("http://%s:%d/%s", host, port, endpoint)
    local suffix = ".json"
    local outfile = tmpdir .. "/tempfile" .. suffix

    local file, err = io.open(outfile, "w")
    if not file then
        print("Error opening file: " .. err)
        return
    end
    file:write(Json.stringify(data))
    file:close()

    -- Use curl to make the POST request with the payload file
    local command = string.format(
        "curl -s -X POST -H 'Content-Type: application/json' -d '@%s' %s >/dev/null 2>&1",
        outfile,
        url
    )
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
    M.post2("127.0.0.1", 3030, "config", config)
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

local convert_line_to_wiki_link = function(line)
    local formatted_line = nil

    if vim.fn.filereadable(line) == 1 then
        local file_path = vim.fn.fnamemodify(line, ":p")
        local file_base_name = vim.fn.fnamemodify(file_path, ":t")
        local suffix = get_file_suffix(file_base_name)
        local file_in_assets = "assets/"
            .. generate_short_uuid()
            .. "."
            .. suffix
        local new_file_path = concat_file_path(M.Cfg.home, file_in_assets)
        local display_path = "/SMP_MD_HOME/" .. file_in_assets
        local mkdirCmd = 'mkdir -p $(dirname "' .. new_file_path .. '")'
        os.execute(mkdirCmd)
        local cpCmd = 'cp "' .. file_path .. '" "' .. new_file_path .. '"'
        os.execute(cpCmd)
        formatted_line = string.format("[%s](%s)", file_base_name, display_path)
    end
    return formatted_line
end

local do_post_data_update = function()
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
            local formatted_line = convert_line_to_wiki_link(aLine)
            if formatted_line ~= nil then
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
        M.log("Pls wait for server start")
        return
    end
    -- M.log("file_path=" .. file_path)
    local fn = vim.fn.expand(file_path)
    -- M.log("fn=" .. fn)
    local linesTobePosted
    local lastlines_key = string.format("buf_%d", bufnr)
    -- M.log("Post data update")

    -- M.log(string.format("\tCheck lines key: %s", lastlines_key))
    local same_content = compare_tables(lines, lastlines[lastlines_key])
    -- M.log(
    --     "\t\tSame content "
    --         .. (same_content and "SameConent" or "NotSameContent")
    -- )
    if same_content then
        -- M.log(" \t\t\tPost NO_CHANGE ")
        linesTobePosted = { "NO_CHANGE" }
    else
        M.log(string.format("\tPost %d lines", #lines))
        linesTobePosted = lines
        lastlines[lastlines_key] = lines
    end

    if fn == nil then
        M.log("WHYYYYYYYYYYY, fn is nil")
    end
    local payload = {
        lines = linesTobePosted,
        pos = pos,
        bufnr = bufnr,
        fn = fn,
        thisline = current_line_text,
    }
    -- print(string.format("%s...%s...%d", "Post", vim.inspect(pos), bufnr))
    if payload.fn then
        M.post2("127.0.0.1", 3030, "update", payload)
    end
    -- M.log("\tPosted")
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

M.get_next_matching_line = function(pattern, start_from)
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

M.do_expand_snippet = function(linenr, show_notfound_warning)
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
    M.do_expand_snippet(linenr, true)
end

M.expand_all_snippets = function()
    local num_lines = vim.api.nvim_buf_line_count(0)

    local start_from = 1

    for _ = 1, num_lines do
        local next_line =
            M.get_next_matching_line(M.snippet_pattern, start_from)
        if next_line > 0 then
            M.log(next_line)
            vim.api.nvim_win_set_cursor(0, { next_line, 0 })
            M.do_expand_snippet(next_line, false)
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
    M.log("Start server NOW!!!")
    lastlines = { "unset" }

    local handle, pid = vim.loop.spawn(cmd, spawn_params)
    -- print("Background process started with PID:", pid)
    if handle then
        -- local bufnr = vim.api.nvim_win_get_buf(0)
        -- print(string.format("%s, %d", "create autocmd in buffer", bufnr))
        M.pid = pid
        M.server_started = true
        M.log("\tStarted, create autocmd ")
        local smp_group =
            vim.api.nvim_create_augroup("smp_group", { clear = true })
        vim.api.nvim_create_autocmd(
            { "CursorHold", "CursorHoldI", "CursorMoved", "CursorMovedI" },
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
            M.log("After server spawn")
            local bufnr = vim.api.nvim_win_get_buf(0)
            local lastlines_key = string.format("buf_%d", bufnr)
            lastlines[lastlines_key] = nil
            do_post_smp_config()
            do_post_data_update()
            -- open browser here
            local function open_browser()
                M.log("Open browser now")
                M.open_url(
                    string.format("http://127.0.0.1:3030/preview/%d", bufnr)
                )
            end
            if openBrowserAfterStart then
                vim.defer_fn(open_browser, 300)
            end
        end
        vim.defer_fn(afterStart, 1000)
    else
        M.server_started = false
        M.log("\tServer start failed")
    end
end

M.cleanup = function()
    M.post2("127.0.0.1", 3030, "stop", {})
    M.server_started = false
end

M.stop = function()
    M.post2("127.0.0.1", 3030, "stop", {})
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
    local function open_browser()
        M.open_url(string.format("http://127.0.0.1:3030/preview/%d", bufnr))
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

M.book = function()
    bookutils.BookShow()
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

M.clear_log()
M.log("\n")

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

return M
