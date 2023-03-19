local Json = require("json")

local vim = vim
local http = require("socket.http")
-- local https = require("ssl.https")
local ltn12 = require("ltn12")
local body = {}
local lastlines = { "unset" }

response = table.concat(body)

local function extract_title(html)
    local title = html:match("<title>(.-)</title>")
    return title
end

function open_url(url)
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

local function is_valid_url(url)
    local url_pattern = "^(https?://[%w-_%.%?%.:/%+=&]+)$"
    return url:match(url_pattern)
end

local function fetch_page_title()
    -- Get the URL from the system clipboard
    local url = vim.fn.getreg("+")

    -- Check if it's a valid URL
    -- if not is_valid_url(url) then
    --     print("Invalid URL.")
    --     return
    -- end

    -- Perform a request to fetch the HTML content
    print("Lookup: ", url)
    local response_body = {}
    local headers = {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36",
    }
    local response_code, response_headers, response_status = http.request({
        method = "GET",
        url = url,
        headers = headers,
        sink = ltn12.sink.table(response_body),
    })

    -- Check if the request was successful
    if response_code ~= 200 then
        print(
            "Error: "
                .. "status:"
                .. vim.inspect(response_status)
                .. "code:"
                .. (response_code or "nil")
                .. vim.inspect(response_body)
        )
        return
    end

    -- Extract the page title from the HTML
    local html = table.concat(response_body)
    local title = extract_title(html)

    -- Print the page title
    if title then
        return { url = url, title = title }
    else
        return nil
    end
end

local M = {}
M.server_started = false
local tmpdir

if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    tmpdir = os.getenv("TEMP")
else
    tmpdir = "/tmp"
end
local logFile = vim.fn.fnamemodify(tmpdir, ":p") .. "smp_client.log"
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

M.post = function(host, port, endpoint, payload)
    -- local json_data = '{"key1": "value1", "key2": "value2"}'
    local json_data = Json.stringify(payload)
    local res_body, code, headers, status = http.request({
        method = "POST",
        url = string.format("http://%s:%d/%s", host, port, endpoint),
        source = ltn12.source.string(json_data),
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = #json_data,
        },
        sink = ltn12.sink.table(body),
    })
    if code ~= 200 then
        print("Post ERROR", code, res_body, status, vim.inspect(headers))
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
    if M.server_started == false then
        M.log("Pls wait for server start")
        return
    end
    -- M.log("file_path=" .. file_path)
    local fn = vim.fn.expand(file_path)
    -- M.log("fn=" .. fn)
    local linesTobePosted = { "no change" }
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
        M.post("127.0.0.1", 3030, "update", payload)
    end
    -- M.log("\tPosted")
end

local post_data_update = create_limited_function(do_post_data_update, 400)

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
        local bufnr = vim.api.nvim_win_get_buf(0)
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
            do_post_data_update()
            -- open browser here
            local function open_browser()
                M.log("Open browser now")
                open_url(
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
    M.post("127.0.0.1", 3030, "stop", {})
    M.server_started = false
end

M.stop = function()
    M.post("127.0.0.1", 3030, "stop", {})
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
        open_url(string.format("http://127.0.0.1:3030/preview/%d", bufnr))
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
M.clear_log()
M.log("\n")

return M
