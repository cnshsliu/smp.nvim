local M = {}

local _synctodo = function(cfg)
    --check mac
    if vim.fn.has("mac") ~= 1 then
        print("Sorry, but synctodo only work for MacOS's Reminders Application")
        return
    end

    --check reminders exists.
    local status, _ = os.execute("which reminders")

    if status ~= 0 then
        print(
            "Please install 'reminders' from https://github.com/keith/reminders-cli"
        )
        return
    end
    --invoke synctodo.sh command
    local plugin_path = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
    local command = plugin_path .. "synctodo.sh"
    -- os.execute(command)
    local spawn_params = {
        command = command,
        args = { M.Cfg.home, M.Cfg.reminders_export_to, ">/dev/null", "2>&1" },
        cwd = plugin_path,
        stdio = { nil, vim.loop.new_pipe(false), vim.loop.new_pipe(false) },
        exit_cb = function(handle, exit_code, signal)
            -- print("Process exited with code:", exit_code, "and signal:", signal)
            handle:close()
        end,
    }
    vim.loop.spawn(command, spawn_params)
end

local _setup = function(cfg)
    M.Cfg = {
        reminders_export_to = "/tmp/reminders_todos.txt",
    }
    local tmpdir
    if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
        tmpdir = os.getenv("TEMP")
    else
        tmpdir = "/tmp"
    end
    M.Cfg.reminders_export_to = vim.fn.fnamemodify(tmpdir, ":p")
        .. "reminders_todos.txt"
    M.Cfg.home = cfg.home
end

M.synctodo = _synctodo
M.setup = _setup
return M
