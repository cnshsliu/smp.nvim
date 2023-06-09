-- local async = require("plenary.async")
local Path = require("plenary.path")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local themes = require("telescope.themes")
local finders = require("telescope.finders")
local NuiTree = require("nui.tree")
local NuiLine = require("nui.line")
local NuiSplit = require("nui.split")
local Keymap = require("nui.utils.keymap")
local scan = require("plenary.scandir")
local Job = require("plenary.job")
local Json = require("book/json")

local inited = false
local _home = vim.fn.expand("~/zettelkasten")
local M = {}
local BookState = {}

local function escape(s)
  return string.gsub(s, "[%%%]%^%-$().[*+?]", "%%%1")
end

local function print_error(s)
  vim.cmd("echohl ErrorMsg")
  vim.cmd("echomsg " .. '"' .. s .. '"')
  vim.cmd("echohl None")
end

local function defaultConfig(home)
  if home == nil then
    home = _home
  end

  local cfg = {
    home = home,
    extension = ".md",
    templates = home .. "/" .. "templates",
    book_use_emoji = true,
  }
  M.Cfg = cfg
end

local function check_dir_and_ask(dir, purpose)
  local ret = false
  if dir ~= nil and Path:new(dir):exists() == false then
    vim.ui.select({ "No (default)", "Yes" }, {
      prompt = "SimpleMarkdownPreview: "
          .. purpose
          .. " folder "
          .. dir
          .. " does not exist!"
          .. " Shall I create it? ",
    }, function(answer)
      if answer == "Yes" then
        if
            Path:new(dir):mkdir({ parents = true, exists_ok = false })
        then
          vim.cmd('echomsg " "')
          vim.cmd('echomsg "' .. dir .. ' created"')
          ret = true
        else
          -- unreachable: plenary.Path:mkdir() will error out
          print_error("Could not create directory " .. dir)
          ret = false
        end
      end
    end)
  else
    ret = true
  end
  return ret
end

local function Setup(cfg)
  cfg = cfg or {}
  defaultConfig(cfg.home)
  local debug = cfg.debug
  for k, v in pairs(cfg) do
    M.Cfg[k] = v
    if debug then
      print(
        "Setup() setting `" .. k .. "`   ->   `" .. tostring(v) .. "`"
      )
    end
  end
  if debug then
    print("Resulting config:")
    print("-----------------")
    print(vim.inspect(M.Cfg))
  end

  M.Cfg.rg_pcre = false
  local has_pcre =
      os.execute("echo 'hello' | rg --pcre2 hello > /dev/null 2>&1")
  if has_pcre == 0 then
    M.Cfg.rg_pcre = true
  end
end

local function _setup(cfg)
  Setup(cfg)
end
M.setup = _setup

local Pinfo = {
  fexists = false,
  title = "",
  filename = "",
  filepath = "",
  root_dir = "",
  sub_dir = "",
  is_daily_or_weekly = false,
  is_daily = false,
  is_weekly = false,
  template = "",
  calendar_info = nil,
}

function Pinfo:new(opts)
  opts = opts or {}

  local object = {}
  setmetatable(object, self)
  self.__index = self
  if opts.filepath then
    return object:resolve_path(opts.filepath, opts)
  end
  if opts.title ~= nil then
    return object:resolve_link(opts.title, opts)
  end
  return object
end

local function file_exists(fname)
  if fname == nil then
    return false
  end

  local f = io.open(fname, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

--- resolve_path(p, opts)
--- inspects the path and returns a Pinfo table
function Pinfo:resolve_path(p, opts)
  opts = opts or {}
  opts.subdirs_in_links = opts.subdirs_in_links or M.Cfg.subdirs_in_links

  self.fexists = file_exists(p)
  self.filepath = p
  self.root_dir = M.Cfg.home
  self.is_daily_or_weekly = false
  self.is_daily = false
  self.is_weekly = false

  -- strip all dirs to get filename
  local pp = Path:new(p)
  local p_splits = pp:_split()
  self.filename = p_splits[#p_splits]
  self.title = self.filename:gsub(M.Cfg.extension, "")

  if vim.startswith(p, M.Cfg.home) then
    self.root_dir = M.Cfg.home
  end
  -- now work out subdir relative to root
  self.sub_dir = p:gsub(escape(self.root_dir .. "/"), "")
      :gsub(escape(self.filename), "")
      :gsub("/$", "")
      :gsub("^/", "")

  if opts.subdirs_in_links and #self.sub_dir > 0 then
    self.title = self.sub_dir .. "/" .. self.title
  end

  return self
end

function Pinfo:resolve_link(title, opts)
  opts = opts or {}
  opts.weeklies = opts.weeklies or M.Cfg.weeklies
  opts.dailies = opts.dailies or M.Cfg.dailies
  opts.home = opts.home or M.Cfg.home
  opts.extension = opts.extension or M.Cfg.extension
  opts.template_handling = opts.template_handling or M.Cfg.template_handling
  opts.new_note_location = opts.new_note_location or M.Cfg.new_note_location

  self.fexists = false
  self.title = title
  self.filename = title .. opts.extension
  self.filename = self.filename:gsub("^%./", "")   -- strip potential leading ./
  self.root_dir = opts.home
  self.is_daily_or_weekly = false
  self.is_daily = false
  self.is_weekly = false
  self.template = nil
  self.calendar_info = nil

  if opts.weeklies and file_exists(opts.weeklies .. "/" .. self.filename) then
    -- TODO: parse "title" into calendarinfo like below
    -- not really necessary as the file exists anyway and therefore we don't need to instantiate a template
    -- if we still want calendar_info, just move the code for it out of `if self.fexists == false`.
    self.filepath = opts.weeklies .. "/" .. self.filename
    self.fexists = true
    self.root_dir = opts.weeklies
    self.is_daily_or_weekly = true
    self.is_weekly = true
  end
  if opts.dailies and file_exists(opts.dailies .. "/" .. self.filename) then
    -- TODO: parse "title" into calendarinfo like below
    -- not really necessary as the file exists anyway and therefore we don't need to instantiate a template
    -- if we still want calendar_info, just move the code for it out of `if self.fexists == false`.
    self.filepath = opts.dailies .. "/" .. self.filename
    self.fexists = true
    self.root_dir = opts.dailies
    self.is_daily_or_weekly = true
    self.is_daily = true
  end
  if file_exists(opts.home .. "/" .. self.filename) then
    self.filepath = opts.home .. "/" .. self.filename
    self.fexists = true
  end

  if self.fexists == false then
    -- now search for it in all subdirs
    local subdirs = scan.scan_dir(opts.home, { only_dirs = true })
    local tempfn
    for _, folder in pairs(subdirs) do
      tempfn = folder .. "/" .. self.filename
      -- [[testnote]]
      if file_exists(tempfn) then
        self.filepath = tempfn
        self.fexists = true
        -- print("Found: " ..self.filename)
        break
      end
    end
  end

  -- now work out subdir relative to root
  self.sub_dir = self.filepath
      :gsub(escape(self.root_dir .. "/"), "")
      :gsub(escape(self.filename), "")
      :gsub("/$", "")
      :gsub("^/", "")

  return self
end

-- Copied from tagutils and modified to fit book function need.
local hashtag_re =
"(^|\\s|'|\")#[a-zA-ZÀ-ÿ\\p{Script=Han}]+[a-zA-ZÀ-ÿ0-9/\\-_\\p{Script=Han}]*"
-- PCRE hashtag allows to remove the hex color codes from hastags
local hashtag_re_pcre = "(^|\\s|'|\")((?!(#[a-fA-F0-9]{3})(\\W|$)|(#[a-fA-F0-9]{6})(\\W|$))"
    .. "#[a-zA-ZÀ-ÿ\\p{Script=Han}]+[a-zA-ZÀ-ÿ0-9/\\-_\\p{Script=Han}]*)"
local colon_re =
"(^|\\s):[a-zA-ZÀ-ÿ\\p{Script=Han}]+[a-zA-ZÀ-ÿ0-9/\\-_\\p{Script=Han}]*:"
local yaml_re =
"(^|\\s)tags:\\s*\\[\\s*([a-zA-ZÀ-ÿ\\p{Script=Han}]+[a-zA-ZÀ-ÿ0-9/\\-_\\p{Script=Han}]*(,\\s*)*)*\\s*]"

local function command_find_all_tags(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or "."
  opts.templateDir = opts.templateDir or ""
  opts.rg_pcre = opts.rg_pcre or false

  -- do not list tags in the template directory
  local globArg = ""
  -- print(vim.inspect(opts))
  if opts.templateDir ~= "" then
    globArg = "--glob=!" .. "**/" .. opts.templateDir .. "/*.md"
  end

  local re = hashtag_re

  if opts.tag_notation == ":tag:" then
    re = colon_re
  end

  if opts.tag_notation == "yaml-bare" then
    re = yaml_re
  end

  local rg_args = {
    "--vimgrep",
    globArg,
    "-o",
    re,
    "--",
    opts.this_file or opts.cwd,
  }

  -- PCRE engine allows to remove hex color codes from #hastags
  if opts.rg_pcre and (re == hashtag_re) then
    re = hashtag_re_pcre

    rg_args = {
      "--vimgrep",
      "--pcre2",
      globArg,
      "-o",
      re,
      "--",
      opts.this_file or opts.cwd,
    }
  end

  return "rg", rg_args
end

-- strips away leading ' or " , then trims whitespace
local function trim(s)
  if s:sub(1, 1) == '"' or s:sub(1, 1) == "'" then
    s = s:sub(2)
  end
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function insert_tag(tbl, tag, entry)
  entry.t = tag
  if tbl[tag] == nil then
    tbl[tag] = { entry }
  else
    tbl[tag][#tbl[tag] + 1] = entry
  end
end

local function split(line, sep, n)
  local startpos = 0
  local endpos
  local ret = {}
  for _ = 1, n - 1 do
    endpos = line:find(sep, startpos + 1)
    ret[#ret + 1] = line:sub(startpos + 1, endpos - 1)
    startpos = endpos
  end
  -- now the remainder
  ret[n] = line:sub(startpos + 1)
  return ret
end

local function yaml_to_tags(line, entry, ret)
  local _, startpos = line:find("tags%s*:%s*%[")
  local global_end = line:find("%]")

  line = line:sub(startpos + 1, global_end)

  local i = 1
  local j
  local prev_i = 1
  local tag
  while true do
    i, j = line:find("%s*(%S*)%s*,", i)
    if i == nil then
      tag = line:sub(prev_i)
      tag = tag:gsub("%s*(%S*)%s*", "%1")
    else
      tag = line:sub(i, j)
      tag = tag:gsub("%s*(%S*)%s*,", "%1")
    end

    local new_entry = {}

    -- strip trailing ]
    tag = tag:gsub("]", "")
    new_entry.t = tag
    new_entry.l = entry.l
    new_entry.fn = entry.fn
    new_entry.c = startpos + (i or prev_i)
    insert_tag(ret, tag, new_entry)
    if i == nil then
      break
    end
    i = j + 1
    prev_i = i
  end
end

local function parse_entry(opts, line, ret)
  local s = split(line, ":", 4)
  local fn, l, c, t = s[1], s[2], s[3], s[4]

  t = trim(t)
  local entry = { fn = fn, l = l, c = c }

  if opts.tag_notation == "yaml-bare" then
    yaml_to_tags(t, entry, ret)
  elseif opts.tag_notation == ":tag:" then
    insert_tag(ret, t, entry)
  else
    insert_tag(ret, t, entry)
  end
end

-- helper function to check if a table contains a specific value
local function table_contains(table, val)
  for _, value in pairs(table) do
    if value == val then
      return true
    end
  end
  return false
end

-- local _log = function(message)
--     local log_file_path = "/tmp/tkbooklog.log"
--     local log_file = assert(io.open(log_file_path, "a"))
--     log_file:write(message .. "\n")
--     log_file:close()
-- end

local saveSearch = function()
  local json_file_path = M.Cfg.home .. "/saved_search.json"
  local json_file = assert(io.open(json_file_path, "w"))
  json_file:write(Json.stringify(BookState.saved_search))
  json_file:close()
end

local ensureConfigFile = function(fn)
  local f = io.open(fn, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    os.execute('mkdir -p $(dirname "' .. fn .. '")')
    os.execute('touch "' .. fn .. '"')
    f = assert(io.open(fn, "w"))
    f:write(Json.stringify({ tag = {}, text = {} }))
    f:close()
    return false
  end
end

local writeOneSavedSearch = function(key, value)
  local data = BookState.saved_search[BookState.search_what]
  local newData = {}
  newData[1] = { key = key, value = value }
  for _, entry in ipairs(data) do
    if entry.key ~= key then
      newData[#newData + 1] = entry
    end
  end
  BookState.saved_search[BookState.search_what] = newData
  saveSearch()
end

local do_find_all_tags = function(opts)
  opts = opts or BookState.opts
  local cmd, args = command_find_all_tags(opts)
  -- print(cmd .. " " .. vim.inspect(args))
  local ret = {}
  local _ = Job:new({
    command = cmd,
    args = args,
    enable_recording = true,
    on_exit = function(j, return_val)
      if return_val == 0 then
        for _, line in pairs(j:result()) do
          parse_entry(opts, line, ret)
        end
      else
        print("rg return value: " .. tostring(return_val))
        print("stderr: ", vim.inspect(j:stderr_result()))
      end
    end,
    on_stderr = function(err, data, _)
      print("error:>> " .. tostring(err) .. "   data: " .. data)
    end,
  }):sync()
  -- sort tags now
  return ret
end

-- The above code is copied from tagutils.

local function command_find_file(opts, pattern)
  local globArg = "--glob=!" .. "**/" .. opts.templates .. "/*.md"

  local rg_args = {
    globArg,
    "-tmarkdown",
    "--files-with-matches",
    "--no-messages",
    "-i",
    "-e",
    pattern,
    "--",
    opts.home,
  }

  return "rg", rg_args
end

local _loadSavedSearch = function()
  local searchHistoryFile = M.Cfg.home .. "/saved_search.json"
  ensureConfigFile(searchHistoryFile)
  local f = io.open(searchHistoryFile, "rb")
  if f == nil then
    BookState.should_save_search = false
    return { tag = {}, text = {} }
  else
    BookState.should_save_search = true
    local content = f:read("*all")
    f:close()
    local ret = Json.parse(content)
    return ret
  end
end
local _init = function()
  inited = true
  BookState = {
    tag_scanned = false,
    file_tags_map = {},
    search_what = "tag",
    last_search_prompt = {},
    book_tree = nil,
  }
  BookState.saved_search = _loadSavedSearch()
end

local _searchOnePattern = function(pattern)
  local cmd, args = command_find_file(M.Cfg, pattern)
  local ret = {}
  local _ = Job:new({
    command = cmd,
    args = args,
    enable_recording = true,
    on_exit = function(j, return_val)
      if return_val == 0 then
        for _, line in pairs(j:result()) do
          if ret[line] == nil then
            ret[#ret + 1] = line
          end
        end
        -- else
        --     print("rg return value: " .. tostring(return_val) .. cmd)
        -- print("stderr: ", vim.inspect(j:stderr_result()))
      end
    end,
    on_stderr = function(err, data, _)
      print("error: " .. tostring(err) .. "data: " .. data)
    end,
  }):sync()
  -- print("final results: " .. vim.inspect(ret))
  return ret
end

local _filterTags = function(logic, A, B, C)
  -- check if A contains all elements of B and no elements from C
  local contains_all_b = true
  local contains_any_b = false
  local contains_no_c = true
  for _, b_elem in ipairs(B) do
    if not table_contains(A, b_elem) then
      contains_all_b = false
      break
    end
  end
  for _, b_elem in ipairs(B) do
    if table_contains(A, b_elem) then
      contains_any_b = true
      break
    end
  end
  for _, c_elem in ipairs(C) do
    if table_contains(A, c_elem) then
      contains_no_c = false
      break
    end
  end

  -- output results
  if logic == "and" then
    if contains_all_b and contains_no_c then
      return true
    else
      return false
    end
  else
    if contains_any_b and contains_no_c then
      return true
    else
      return false
    end
  end
end

local _split_and_trim = function(str, delimiter)
  local substrings = {}
  local pattern = "[^" .. delimiter .. "]+"
  for substring in string.gmatch(str, pattern) do
    table.insert(substrings, (string.gsub(substring, "^%s*(.-)%s*$", "%1")))
  end
  return substrings
end

-- TODO: cache mtimes and only update if changed

-- The reason we go over all notes in one go, is: backlinks
-- We generate 2 maps: one containing the number of links within a note
--    and a second one containing the number of backlinks to a note
-- Since we're parsing all notes anyway, we can mark linked notes as backlinked from the currently parsed note
local _generate_book_map = function(mytitle)
  local opts = M.Cfg
  assert(opts ~= nil, "opts must not be nil")
  -- TODO: check for code blocks
  -- local in_fenced_code_block = false
  -- also watch out for \t tabbed code blocks or ones with leading spaces that don't end up in a - or * list

  -- first, find all notes
  assert(opts.extension ~= nil, "Error: need extension in opts!")
  assert(opts.home ~= nil, "Error: need home dir in opts!")

  -- async seems to have lost await and we don't want to enter callback hell, hence we go sync here
  -- local subdir_list = scan.scan_dir(opts.home, { only_dirs = true })
  local file_list = {}
  -- transform the file list
  local _x = scan.scan_dir(opts.home, {
    search_pattern = function(entry)
      return entry:sub(- #opts.extension) == opts.extension
    end,
  })

  for _, v in pairs(_x) do
    file_list[v] = true
  end

  BookState.note_list = file_list

  -- now process all the notes
  local backlinks = {}
  for note_fn, _ in pairs(file_list) do
    -- go over file line by line
    local found = false
    for line in io.lines(note_fn) do
      if line:match("%[%[" .. mytitle .. "%]%]") then
        found = true
        break
      end
    end
    if found then
      backlinks[note_fn] = true
    end
  end

  return backlinks
end

local _find_buffer_by_name = function(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(buf)
    if buf_name == name then
      return buf
    end
  end
  return -1
end

-- local _get_modified_buffers = function()
--     local modified_buffers = {}
--     for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
--         local buffer_name = vim.api.nvim_buf_get_name(buffer)
--         if buffer_name == nil or buffer_name == "" then
--             buffer_name = "[No Name]#" .. buffer
--         end
--         modified_buffers[buffer_name] =
--             vim.api.nvim_buf_get_option(buffer, "modified")
--     end
--     return modified_buffers
-- end

local _open_file = function(winid_openin, winid_from, path, open_cmd)
  local escaped_path = vim.fn.fnameescape(path)
  open_cmd = open_cmd or "edit"
  if open_cmd == "edit" or open_cmd == "e" then
    -- If the file is already open, switch to it.
    local bufnr = _find_buffer_by_name(path)
    if bufnr > 0 then
      open_cmd = "b"
    end
  end
  vim.api.nvim_set_current_win(winid_openin)
  pcall(vim.cmd, open_cmd .. " " .. escaped_path)
  -- vim.cmd(open_cmd .. " " .. escaped_path)

  vim.api.nvim_set_current_win(winid_from)
end

-- local redrawHeaderNodes = function(tree)
--     local nodes = tree:get_nodes("__headers")
--     for _, node in ipairs(nodes) do
--         print(node.text)
--         if node.type == "t_header" then
--             node.text = "⊢" .. node.text
--         end
--     end
-- end

local _revisit = function()
  -- get all notes link to this note
  local backlink_title = {}
  local backlinks = _generate_book_map(BookState.center_note.title)
  for backlink_note, _ in pairs(backlinks) do
    backlink_title[#backlink_title + 1] = {
      title = Pinfo:new({ filepath = backlink_note, M.Cfg }).title,
      filepath = backlink_note,
      fexists = true,
    }
  end

  -- print(vim.inspect(BookState.opts))
  --
  -- get all notes link from this note
  -- and, get all todo items in this note
  -- also, get all headers in this note
  local linksInNote = {}
  local todoInNote = {}
  local headers = {}
  local tmp = vim.api.nvim_buf_get_lines(BookState.main_bufnr, 0, -1, false)
  for _, line in pairs(tmp) do
    for w in string.gmatch(line, "%[%[(.-)%]%]") do
      local tmpInfo = Pinfo:new({ title = w, M.Cfg })
      linksInNote[#linksInNote + 1] = {
        ln = _,
        link = w,
        filepath = tmpInfo.filepath,
        fexists = tmpInfo.fexists,
      }
    end
    local todoMatch = string.match(line, "- %[[ ]%] (.+)$")
    if todoMatch ~= nil then
      todoInNote[#todoInNote + 1] = { ln = _, todo = todoMatch }
    end
    local hashes, headerText = string.match(line, "^%s*(#+)%s(.-)$")
    if hashes ~= nil then
      headers[#headers + 1] = {
        ln = _,
        header = headerText,
        level = string.len(hashes),
      }
    end
  end

  BookState.opts.this_file = BookState.center_note.filepath
  local tag_map = do_find_all_tags()

  local tmpArr = {}
  for k, _ in pairs(tag_map) do
    tmpArr[#tmpArr + 1] = k
  end
  table.sort(tmpArr, function(a, b)
    return a < b
  end)

  local max_tag_len = 0
  local taglist = {}
  for _, k in ipairs(tmpArr) do
    taglist[#taglist + 1] = { tag = k, details = tag_map[k] }
    if #k > max_tag_len then
      max_tag_len = #k
    end
  end
  -- print("final results: " .. vim.inspect(taglist))

  local nodes = {}
  table.insert(
    nodes,
    NuiTree.Node({
      id = "__BRAIN",
      text = (BookState.opts.book_use_emoji and "🧠" or "#")
          .. " "
          .. BookState.center_note.title,
    })
  )
  -- table.insert(nodes, NuiTree.Node({ text = "  " }))
  local tagNodes = {}
  for _, entry in pairs(taglist) do
    -- local display = string.format(
    --     "%" .. max_tag_len .. "s ... (%3d matches)",
    --     entry.tag,
    --     #entry.details
    -- )
    local display = entry.tag .. " (" .. #entry.details .. ")"

    table.insert(
      tagNodes,
      NuiTree.Node({
        text = display,
        type = "tag",
        matches = #entry.details,
        details = entry.details,
      })
    )
  end
  table.insert(
    nodes,
    NuiTree.Node({
      id = "__tags",
      text = (BookState.opts.book_use_emoji and "🏷️" or "#")
          .. " Tags",
    }, tagNodes)
  )
  local linkNodes = {}
  for _, entry in pairs(backlink_title) do
    local display = "[[" .. entry.title .. "]]"
    table.insert(
      linkNodes,
      NuiTree.Node({
        text = display,
        filepath = entry.filepath,
        fexists = entry.fexists,
        type = "backlink",
        ser = _,
      })
    )
  end
  table.insert(
    linkNodes,
    NuiTree.Node({
      text = (BookState.opts.book_use_emoji and "⭐️" or ">>")
          .. " "
          .. BookState.center_note.title
          .. " "
          .. (BookState.opts.book_use_emoji and "⭐️" or "<<"),
      id = "__centernote",
      filepath = BookState.center_note.filepath,
      fexists = true,
      type = "centernote",
      ser = #backlink_title + 1,
    })
  )
  for _, entry in pairs(linksInNote) do
    local display = "[[" .. entry.link .. "]]"
    table.insert(
      linkNodes,
      NuiTree.Node({
        text = display,
        filepath = entry.filepath,
        fexists = entry.fexists,
        ser = #backlink_title + 1 + _,
        type = "link",
      })
    )
  end
  table.insert(
    nodes,
    NuiTree.Node({
      id = "__links",
      text = (BookState.opts.book_use_emoji and "🔗" or "#")
          .. " Links",
    }, linkNodes)
  )

  local todoNodes = {}
  for _, entry in pairs(todoInNote) do
    local display = "[ ]" .. entry.todo
    -- local display = entry.todo
    --TODO: add line number to node data
    table.insert(
      todoNodes,
      NuiTree.Node({
        text = display,
        ser = _,
        l = entry.ln,
        type = "todo",
      })
    )
  end
  table.insert(
    nodes,
    NuiTree.Node({
      id = "__todos",
      text = (BookState.opts.book_use_emoji and "❎" or "#") .. " Todos",
    }, todoNodes)
  )

  local headerNodes = {}
  for _, entry in ipairs(headers) do
    local display = entry.header .. " H" .. entry.level
    table.insert(
      headerNodes,
      NuiTree.Node({
        text = display,
        ser = _,
        l = entry.ln,
        type = "t_header",
        level = entry.level,
      })
    )
  end
  table.insert(
    nodes,
    NuiTree.Node({
      id = "__headers",
      text = (BookState.opts.book_use_emoji and "🅷" or "#")
          .. " Headers",
    }, headerNodes)
  )
  table.insert(
    nodes,
    NuiTree.Node({
      id = "__search",
      text = (BookState.opts.book_use_emoji and "🔎" or "#")
          .. " Search",
    }, {
      NuiTree.Node({
        text = "?: see help",
        ser = 1,
        type = "search_help",
      }),
    })
  )

  local tree = NuiTree({
    winid = BookState.book_win,
    bufnr = BookState.book_bufnr,
    nodes = nodes,
    get_node_id = function(node)
      if node.id then
        return node.id
      end
      return "-" .. math.random()
    end,
    prepare_node = function(node)
      local line = NuiLine()

      if node.id ~= "__BRAIN" then
        line:append(string.rep(" ", node:get_depth() - 1))
      end

      if node:has_children() then
        line:append(
          node:is_expanded() and " " or " ",
          "SpecialChar"
        )
      else
        if node.id ~= "__BRAIN" then
          line:append("  ")
        end
        if node.type == "t_header" then
          line:append(string.rep(" ", node.level))
        end
      end

      line:append(node.text)

      return line
    end,
  })

  BookState.section_tag_line = 2
  BookState.section_link_line = BookState.section_tag_line + #tagNodes + 1
  BookState.center_note_line = BookState.section_link_line
      + #backlink_title
      + 1
  BookState.section_todo_line = BookState.center_note_line + #linksInNote + 1
  BookState.section_header_line = BookState.section_todo_line + #todoNodes + 1
  BookState.section_search_line = BookState.section_header_line
      + #headerNodes
      + 1

  -- parent links
  if #backlink_title > 0 then
    BookState.parent_lines = {
      BookState.center_note_line - #backlink_title,
      BookState.center_note_line - 1,
    }
  else
    BookState.parent_lines = nil
  end

  -- children links
  if #linksInNote > 0 then
    BookState.children_lines = {
      BookState.center_note_line + 1,
      BookState.center_note_line + #linksInNote,
    }
  else
    BookState.children_lines = nil
  end

  tree:render()
  return tree
end

local _BookGotoCenterNote = function()
  vim.api.nvim_set_current_win(BookState.main_win)
  _open_file(
    BookState.main_win,
    BookState.book_win,
    BookState.center_note.filepath,
    "edit"
  )
  vim.api.nvim_set_current_win(BookState.book_win)
  vim.api.nvim_win_set_cursor(
    BookState.book_win,
    { BookState.center_note_line, 6 }
  )
end

local showHelp = function()
  local Popup = require("nui.popup")
  local event = require("nui.utils.autocmd").event

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = "[ Help ]",
        top_align = "center",
      },
      padding = {
        top = 1,
        left = 2,
      },
    },
    relative = "editor",
    position = "50%",
    size = {
      width = "80%",
      height = "60%",
    },
    ns_id = "SimpleMarkdownPreview.nvim",
    buf_options = {
      buftype = "nofile",
      modifiable = true,
      swapfile = false,
      filetype = "text",
      undolevels = -1,
    },
  })

  -- mount/open the component
  popup:mount()

  -- unmount component when cursor leaves buffer
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)
  popup:map("n", "<esc>", function()
    vim.cmd("q")
  end, { noremap = true })
  popup:map("n", "q", function()
    vim.cmd("q")
  end, { noremap = true })
  popup:map("n", "?", function()
    vim.cmd("q")
  end, { noremap = true })

  -- set content
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, {
    "SimpleMarkdowPreview show_book (tkbook):                 ",
    "  . Outline note structure includes tags/links/todos/headers.",
    "  . Incremental search by tags or content.",
    "  . Save search, and saved search picker.",
    "",
    "  f   outline current note strucutre",
    "  gc  go to center note                    gt  go to tags",
    "  gl  go to links                          gd  got to todos",
    "  gh  got to headers                       gs  got to search",
    "  <CR> on tag:       highlight tags        <C-CR> on tag:       jump to tags",
    "  <CR> on link:      show linked note      <C-CR> on link:      jump to linked note",
    "  <CR> on header:    show linked header    <C-CR> on header:    jump to header",
    "  <CR> on todo:      show linked header    <C-CR> on todo:      jump to todo",
    "  <CR> on search:    show result note      <C-CR> on search:    jump to result note",
    "  ?   bring up this help                   q   close tkbook",
    "",
    "",
    "How to search",
    "  st  search by tags                       rt  rescan and search",
    "  sx  search by content                    rx  rescan and search",
    "  then search picker window will popup, input search conditons like:",
    "      [:save_by_name] word1 word2 [or] [-word3]",
    "  the order of these elements does not matter, as many words as you like",
    "    . whithout 'or': match word1 AND word2, but not word3",
    "    . whith 'or':    match word1 OR word2, but not word3",
    "    . save_by_name is used as save-as short name for your search condition",
    "  while you are typing search condition, any matched previously saved search will be displayed below,",
    "  move cursor onto one of them, the saved conditon will be displayed in th above preview window",
    "    . press <CR> to pick it and search by its saved conditions  ",
    "    . press <C-CR> to search by any conditons you input, and save the conditons",
    "  If you change a note, remember to use rt/rx to rescan.",
    "",
    "q, <esc>, ? to close this help",
  })
  vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", false)
end

local parseSearchUserInput = function(user_input)
  user_input = user_input or BookState.user_input
  local ret = {}
  local input_tags = _split_and_trim(user_input, ", ")
  ret.B = {}   -- want
  ret.C = {}   -- dont' want
  ret.logic = "and"
  ret.search_name = ""
  for _, tag in ipairs(input_tags) do
    if tag == "and" or tag == "or" then
      if tag == "or" then
        ret.logic = "or"
      end
    elseif string.sub(tag, 1, 1) == ":" then
      ret.search_name = string.sub(tag, 2)
    else
      if string.sub(tag, 1, 1) == "-" then
        table.insert(ret.C, tag:sub(2))
      else
        table.insert(ret.B, tag)
      end
    end
  end
  return ret
end

local get_tag_matched_files = function()
  -- example usage
  local tmp = parseSearchUserInput()
  for fn, ftags in pairs(BookState.file_tags_map) do
    if #ftags > 0 then
      local checkResult = _filterTags(tmp.logic, ftags, tmp.B, tmp.C)
      if checkResult then
        BookState.search_result[#BookState.search_result + 1] = fn
      end
    end
  end
end

local get_text_matched_files = function()
  -- example usage
  local si = parseSearchUserInput()
  local logic = si.logic
  local B = si.B
  local C = si.C
  local ret = {}
  local cache = {}
  local tmp = {}
  for _, pattern in ipairs(B) do
    local files = _searchOnePattern(pattern)
    for _, file in ipairs(files) do
      if tmp[file] == nil then
        tmp[file] = 1
      else
        tmp[file] = tmp[file] + 1
      end
    end
  end

  if logic == "and" then
    for file, count in pairs(tmp) do
      if count == #B then
        cache[#cache + 1] = file
      end
    end
  else
    for file, _ in pairs(tmp) do
      cache[#cache + 1] = file
    end
  end

  tmp = {}
  for _, pattern in ipairs(C) do
    local files = _searchOnePattern(pattern)
    for _, file in ipairs(files) do
      if tmp[file] == nil then
        tmp[file] = 1
      else
        tmp[file] = tmp[file] + 1
      end
    end
  end
  for _, file in ipairs(cache) do
    if tmp[file] == nil then
      ret[#ret + 1] = file
    end
  end

  BookState.search_result = ret
  return ret
end

local expand_section = function(section, toRender)
  local node, _ = BookState.book_tree:get_node(section)
  if node:expand() then
    if toRender then
      BookState.book_tree:render()
    end
  end
end

local executeSearch = function(value)
  BookState.user_input = value
  if (not BookState.tag_scanned) or BookState.rescan then
    BookState.file_tags_map = {}
    _generate_book_map(BookState.center_note.title)
    for fn, _ in pairs(BookState.note_list) do
      BookState.opts.this_file = fn
      BookState.file_tags_map[fn] = {}
      local tag_map = do_find_all_tags()
      local ftags = {}
      for k, _ in pairs(tag_map) do
        ftags[#ftags + 1] = string.sub(k, 2)
      end
      BookState.file_tags_map[fn] = ftags
    end
    BookState.tag_scanned = true
    print("Scanning books ... done")
  end
  BookState.search_result = {}
  if BookState.search_what == "tag" then
    get_tag_matched_files()
  else
    get_text_matched_files()
  end

  local buildSearchResultTree = function()
    local result_nodes = {}
    table.insert(
      result_nodes,
      NuiTree.Node({
        text = "/"
            .. BookState.last_search_prompt[BookState.search_what],
        prompt = BookState.last_search_prompt[BookState.search_what],
        ser = 0,
        type = "search_last_prompt",
        filepath = nil,
      })
    )

    if #BookState.search_result == 0 then
      table.insert(
        result_nodes,
        NuiTree.Node({
          text = "0 matched",
          ser = 1,
          type = "search_result_nothing",
        })
      )
    else
      for _, entry in ipairs(BookState.search_result) do
        local note = Pinfo:new({ filepath = entry, M.Cfg })
        table.insert(
          result_nodes,
          NuiTree.Node({
            text = "[[" .. note.title .. "]]",
            ser = _,
            type = "search_result_note",
            filepath = note.filepath,
            fexists = true,
          })
        )
      end
    end
    -- should I put search result into book view?
    BookState.book_tree:set_nodes(result_nodes, "__search")
    expand_section("__search", false)
    BookState.book_tree:render()
  end
  buildSearchResultTree()

  return { "Done" }
end

local get_section_linenr = function(section)
  local _, linenr = BookState.book_tree:get_node(section)
  return linenr
end

local rescan_section_lines = function()
  BookState.section_tag_line = get_section_linenr("__tags")
  BookState.section_link_line = get_section_linenr("__links")
  BookState.section_todo_line = get_section_linenr("__todos")
  BookState.section_header_line = get_section_linenr("__headers")
  BookState.section_search_line = get_section_linenr("__search")
  BookState.center_note_line = get_section_linenr("__centernote")
end

local _promptSearchInput = function(opts)
  -- move to search section
  rescan_section_lines()
  local tot_ln = vim.api.nvim_buf_line_count(BookState.book_bufnr)
  local move_cursor_to = BookState.section_search_line
      + (tot_ln > BookState.section_search_line and 1 or 0)
  pcall(
    vim.api.nvim_win_set_cursor,
    BookState.book_win,
    { move_cursor_to, 5 }
  )
  BookState.last_search_prompt = BookState.last_search_prompt or {}
  if BookState.last_search_prompt[BookState.search_what] == nil then
    BookState.last_search_prompt[BookState.search_what] = ""
  end
  local prompt_message = "Enter your input: "
  local user_input = ""

  local previewer = previewers.new_buffer_previewer({
    title = "Saved Conditions Preview",
    get_buffer_by_name = function()
      return {
        value = user_input,
        prompt_message = prompt_message,
      }
    end,
    define_preview = function(self, entry, _)
      local info = parseSearchUserInput(entry.ordinal)
      local lines = {
        "Search: " .. entry.ordinal,
        "",
        "Name: " .. entry.value.key,
        (info.logic == "and" and "AND" or "OR") .. " " .. vim.inspect(
          info.B
        ),
        "Exlude: " .. vim.inspect(info.C),
        "",
        "Press CR to search with this saved conditions",
        "Press Control-CR to search with your input anyway",
        "Press Control-S to save and search",
      }
      if entry.ordinal == "" then
        lines = {
          "Input query condition words separated by blank or ','",
          "  . to make an OR query, have a 'or' in your input, ",
          "  . or else, an AND query will be made (deault)",
          "  . to give your search a short name, use :short_name in your query string",
          "  . -word to exclude it",
          "",
          "Keep typing, matched saved-search will be displayed, select one of them, then",
          "  . Press CR to search with the selected saved conditions",
          "  . Press Control-CR to search with your input anyway",
          "  . Press Control-S to save and search",
        }
      end
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", false)
    end,
  })

  local searchFromPicker = function(search, arg)
    if type(arg) == "boolean" then
      if arg then       -- save search
        local info = parseSearchUserInput(search)
        local sskey = (
          info.search_name ~= "" and info.search_name
          or search
        )
        writeOneSavedSearch(sskey, search)
      end
    elseif arg and arg.ordinal then
      search = arg.ordinal
    end
    BookState.last_search_prompt[BookState.search_what] = search
    executeSearch(search)
  end
  local searchByInputOnly = function()
    return function(prompt_bufnr)
      local search =
          action_state.get_current_picker(prompt_bufnr):_get_prompt()
      -- action_state.get_current_picker(prompt_bufnr).sorter._discard_state.prompt
      actions.close(prompt_bufnr)
      searchFromPicker(search, true)
    end
  end
  local saveThenSearchByInput = function()
    return function(prompt_bufnr)
      local search =
          action_state.get_current_picker(prompt_bufnr):_get_prompt()
      -- vim.api.nvim_buf_get_lines(prompt_bufnr, 0, 1, false)[1]:sub(#self.prompt_prefix + 1)
      -- action_state.get_current_picker(prompt_bufnr).sorter._discard_state.prompt
      actions.close(prompt_bufnr)
      searchFromPicker(search, true)
    end
  end

  local show = function(themOpts)
    themOpts = themOpts or {}

    local result_table = {}
    result_table[1] = {
      key = "Search by "
          .. (BookState.search_what == "tag" and "Tag" or "Text")
          .. ", input query contions above pls.",
      value = "",
    }
    for _, entry in ipairs(BookState.saved_search[BookState.search_what]) do
      result_table[#result_table + 1] = {
        key = entry.key,
        value = entry.value,
      }
    end

    pickers
        .new(themOpts, {
          default_text = (opts.prompt == nil or opts.prompt == "")
              and BookState.last_search_prompt[BookState.search_what]
              or opts.prompt,
          prompt_title = "Search notes by "
              .. (BookState.search_what == "tag" and "Tags" or "Content"),
          -- finder = finders.new_table(BookState.saved_search),
          finder = finders.new_table({
            results = result_table,
            entry_maker = function(entry)
              return {
                value = entry,
                display = entry.key,
                ordinal = entry.value,
              }
            end,
          }),
          sorter = conf.generic_sorter(themOpts),
          previewer = previewer,
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              user_input = action_state
                  .get_current_picker(prompt_bufnr)
                  :_get_prompt()
              actions.close(prompt_bufnr)
              searchFromPicker(
                user_input,
                action_state.get_selected_entry()
              )
            end)
            map("i", "<c-cr>", searchByInputOnly())
            map("n", "<c-cr>", searchByInputOnly())
            map("i", "<c-s>", saveThenSearchByInput())
            map("n", "<c-s>", saveThenSearchByInput())
            return true
          end,
        })
        :find()
  end
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

M.BookQuit = function()
  pcall(vim.api.nvim_del_augroup_by_name, "tkbook")
  BookState.book_split:unmount()
  BookState.book_win = nil
  BookState.book_bufnr = nil
  BookState.book_split = nil
  BookState.loaded = false
  inited = false
end

local _BookMoveCursorTo = function(file)
  if BookState.book_tree and BookState and BookState.section_link_line then
    for _, node in pairs(BookState.book_tree.nodes.by_id) do
      if
          (
            node.type == "link"
            or node.type == "backlink"
            or node.type == "centernote"
          )
          and node.filepath == file
          and node.ser
      then
        vim.api.nvim_win_set_cursor(
          BookState.book_win,
          { BookState.section_link_line + node.ser, 6 }
        )
        break
      end
    end
  end
end

local function global_dir_check()
  local ret
  if M.Cfg.home == nil then
    print_error("Smp.nvim: home is not configured!")
    ret = false
  else
    ret = check_dir_and_ask(M.Cfg.home, "home")
  end

  ret = ret and check_dir_and_ask(M.Cfg.templates, "templates")

  return ret
end

local expand_all = function()
  local updated = false

  for _, node in pairs(BookState.book_tree.nodes.by_id) do
    updated = node:expand() or updated
  end

  if updated then
    BookState.book_tree:render()
  end
end

local _BookShow = function(opts)
  if BookState.loaded then
    M.BookQuit()
    return
  end
  if not global_dir_check() then
    return
  end
  opts.prompt = vim.fn.expand("<cword>")

  local bufname = "SMP Book"
  _init()
  BookState.loaded = true

  if
      BookState.book_bufnr
      and BookState.book_bufnr ~= -1
      and vim.fn.bufexists(BookState.book_bufnr)
  then
    -- The buffer already exists, so delete it and its window
    local winid = vim.fn.bufwinid(BookState.book_bufnr)
    if winid ~= -1 and vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, true)
    end
    pcall(vim.api.nvim_buf_delete, BookState.book_bufnr, { force = true })
  end
  local tk_book_group =
      vim.api.nvim_create_augroup("tkbook", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "telekasten", "markdown" },
    group = tk_book_group,
    callback = function(args)
      if
          BookState.book_tree ~= nil
          and BookState.enable_auto_move_curosr_to_note_line
      then
        -- This is only accurate when all nodes are expaned at this moment
        pcall(_BookMoveCursorTo, args.file)
      end
    end,
  })

  BookState.main_win = vim.api.nvim_get_current_win()
  BookState.main_bufnr = vim.api.nvim_get_current_buf()
  BookState.center_note =
      Pinfo:new({ filepath = vim.fn.expand("%:p"), M.Cfg })
  BookState.center_note_line = -1
  BookState.opts = opts
  BookState.enable_auto_move_curosr_to_note_line = true

  BookState.book_split = NuiSplit({
    ns_id = vim.api.nvim_create_namespace("SimpleMarkdownPreview.nvim"),
    size = 40,
    position = "right",
    relative = "editor",
    buf_options = {
      buftype = "nofile",
      modifiable = false,
      swapfile = false,
      filetype = "smpbook",
      undolevels = -1,
    },
    win_options = {
      colorcolumn = "",
      signcolumn = "no",
    },
  })
  BookState.book_split:mount()
  BookState.book_bufnr = BookState.book_split.bufnr
  vim.api.nvim_buf_set_name(BookState.book_bufnr, bufname)
  BookState.book_win = vim.api.nvim_get_current_win()

  BookState.book_tree = _revisit()

  expand_all()
  vim.api.nvim_win_set_cursor(0, { BookState.center_note_line, 6 })
  local map_options = { noremap = true, nowait = true }

  Keymap.set(BookState.book_bufnr, "n", "q", function()
    M.BookQuit()
  end, { noremap = true })

  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = BookState.book_bufnr,
    callback = function()
      vim.api.nvim_del_augroup_by_name("tkbook")
      BookState.book_split:unmount()
    end,
  })

  local pressEnterOnBookItem = function(withControlKey)
    local node = BookState.book_tree:get_node()
    if
        (
          node.type == "link"
          or node.type == "centernote"
          or node.type == "backlink"
          or node.type == "search_result_note"
        ) and node.filepath
    then
      if node.fexists then
        -- vim.cmd("e " .. node.filepath)
        _open_file(
          BookState.main_win,
          BookState.book_win,
          node.filepath,
          "edit"
        )
      else
        print("File does not exist:" .. " " .. node.filepath)
      end
    elseif node.type == "tag" then
      BookState.enable_auto_move_curosr_to_note_line = false
      if
          vim.api.nvim_buf_get_name(
            vim.api.nvim_win_get_buf(BookState.main_win)
          ) ~= node.details[1].fn
      then
        _open_file(
          BookState.main_win,
          BookState.book_win,
          node.details[1].fn,
          "edit"
        )
      end
      vim.api.nvim_set_current_win(BookState.main_win)
      vim.cmd("/" .. node.details[1].t)
      vim.api.nvim_win_set_cursor(
        BookState.main_win,
        { tonumber(node.details[1].l), tonumber(node.details[1].c) }
      )
      BookState.enable_auto_move_curosr_to_note_line = true
    elseif node.type == "todo" then
      BookState.enable_auto_move_curosr_to_note_line = false
      if
          vim.api.nvim_buf_get_name(
            vim.api.nvim_win_get_buf(BookState.main_win)
          ) ~= BookState.center_note.filepath
      then
        _open_file(
          BookState.main_win,
          BookState.book_win,
          BookState.center_note.filepath,
          "edit"
        )
      end
      vim.api.nvim_set_current_win(BookState.main_win)
      -- vim.cmd("/" .. escape_chars(node.text))
      vim.api.nvim_win_set_cursor(
        BookState.main_win,
        { tonumber(node.l), 7 }
      )
      BookState.enable_auto_move_curosr_to_note_line = true
    elseif node.type == "t_header" then
      BookState.enable_auto_move_curosr_to_note_line = false
      if
          vim.api.nvim_buf_get_name(
            vim.api.nvim_win_get_buf(BookState.main_win)
          ) ~= BookState.center_note.filepath
      then
        _open_file(
          BookState.main_win,
          BookState.book_win,
          BookState.center_note.filepath,
          "edit"
        )
      end
      vim.api.nvim_set_current_win(BookState.main_win)
      vim.api.nvim_win_set_cursor(
        BookState.main_win,
        { tonumber(node.l), 1 }
      )
      BookState.enable_auto_move_curosr_to_note_line = true
    end
    if withControlKey then
      vim.api.nvim_set_current_win(BookState.main_win)
    else
      vim.api.nvim_set_current_win(BookState.book_win)
    end
  end

  Keymap.set(BookState.book_bufnr, "n", "<CR>", function()
    local node = BookState.book_tree:get_node()
    if node:has_children() then
      if node:is_expanded() then
        if node:collapse() then
          BookState.book_tree:render()
        end
      else
        if node:expand() then
          BookState.book_tree:render()
        end
      end
    else
      pressEnterOnBookItem(false)
    end
  end, map_options)

  local promptDemoteHeader = function(withControlKey, pOrD)
    local aNode = BookState.book_tree:get_node()
    if aNode.type ~= "t_header" then
      return
    end
    BookState.enable_auto_move_curosr_to_note_line = false
    if
        vim.api.nvim_buf_get_name(
          vim.api.nvim_win_get_buf(BookState.main_win)
        ) ~= BookState.center_note.filepath
    then
      _open_file(
        BookState.main_win,
        BookState.book_win,
        BookState.center_note.filepath,
        "edit"
      )
    end
    vim.api.nvim_set_current_win(BookState.main_win)
    vim.api.nvim_win_set_cursor(
      BookState.main_win,
      { tonumber(aNode.l), 1 }
    )
    local currentLineText = vim.api.nvim_get_current_line()
    -- Check if the current line is a Markdown header
    if string.sub(currentLineText, 1, 1) == "#" then
      -- Get the header level
      local headerLevel = string.find(currentLineText, "%s") - 1
      print(headerLevel)

      -- Demote the header level
      if headerLevel > 0 then
        local newHeaderLevel = (pOrD == "p") and (headerLevel - 1)
            or (headerLevel + 1)
        if newHeaderLevel > 0 then
          local newHeaderPrefix = string.rep("#", newHeaderLevel)
          local newHeaderText = newHeaderPrefix
              .. string.sub(currentLineText, headerLevel + 1)
          vim.api.nvim_set_current_line(newHeaderText)

          aNode.level = aNode.level + ((pOrD == "p") and -1 or 1)
          aNode.text = string.gsub(
            aNode.text,
            "( H)(%d+)",
            function(prefix, number)
              return prefix .. tostring(aNode.level)
            end
          )
          BookState.book_tree:render()
        end
      end
    end
    BookState.enable_auto_move_curosr_to_note_line = true
    if withControlKey then
      vim.api.nvim_set_current_win(BookState.main_win)
    else
      vim.api.nvim_set_current_win(BookState.book_win)
    end
  end

  Keymap.set(BookState.book_bufnr, "n", "<C-CR>", function()
    pressEnterOnBookItem(true)
  end, map_options)

  Keymap.set(BookState.book_bufnr, "n", ">>", function()
    rescan_section_lines()
    promptDemoteHeader(false, "d")
  end, map_options)
  Keymap.set(BookState.book_bufnr, "n", "<<", function()
    rescan_section_lines()
    promptDemoteHeader(false, "p")
  end, map_options)

  Keymap.set(BookState.book_bufnr, "n", "gc", function()
    rescan_section_lines()
    _BookGotoCenterNote()
  end, map_options)

  Keymap.set(BookState.book_bufnr, "n", "gt", function()
    rescan_section_lines()
    vim.api.nvim_win_set_cursor(
      BookState.book_win,
      { BookState.section_tag_line, 5 }
    )
  end, map_options)
  Keymap.set(BookState.book_bufnr, "n", "gl", function()
    rescan_section_lines()
    vim.api.nvim_win_set_cursor(
      BookState.book_win,
      { BookState.section_link_line, 5 }
    )
  end, map_options)
  Keymap.set(BookState.book_bufnr, "n", "gd", function()
    rescan_section_lines()
    vim.api.nvim_win_set_cursor(
      BookState.book_win,
      { BookState.section_todo_line, 5 }
    )
  end, map_options)
  Keymap.set(BookState.book_bufnr, "n", "gh", function()
    rescan_section_lines()
    vim.api.nvim_win_set_cursor(
      BookState.book_win,
      { BookState.section_header_line, 5 }
    )
  end, map_options)
  Keymap.set(BookState.book_bufnr, "n", "gs", function()
    rescan_section_lines()
    vim.api.nvim_win_set_cursor(
      BookState.book_win,
      { BookState.section_search_line, 5 }
    )
  end, map_options)

  Keymap.set(BookState.book_bufnr, "n", "f", function()
    local linePos = vim.api.nvim_win_get_cursor(BookState.book_win)
    vim.api.nvim_set_current_win(BookState.main_win)
    BookState.main_bufnr = vim.api.nvim_get_current_buf()
    BookState.center_note =
        Pinfo:new({ filepath = vim.fn.expand("%:p"), M.Cfg })
    vim.api.nvim_set_current_win(BookState.book_win)
    BookState.book_tree.nodes = {}
    BookState.book_tree = _revisit()
    expand_all()
    vim.api.nvim_win_set_cursor(0, { BookState.center_note_line, 6 })
    pcall(vim.api.nvim_win_set_cursor, 0, linePos)
  end, map_options)

  -- collapse current node
  Keymap.set(BookState.book_bufnr, "n", "c", function()
    local node = BookState.book_tree:get_node()

    if node:has_children() == false then
      node = BookState.book_tree:get_node(node:get_parent_id())
    end

    if node:is_expanded() then
      if node:collapse() then
        BookState.book_tree:render()
      end
    end
  end, map_options)

  -- collapse all nodes
  Keymap.set(BookState.book_bufnr, "n", "C", function()
    local updated = false

    for _, node in pairs(BookState.book_tree.nodes.by_id) do
      updated = node:collapse() or updated
    end

    if updated then
      BookState.book_tree:render()
    end
  end, map_options)

  -- expand current node
  Keymap.set(BookState.book_bufnr, "n", "e", function()
    local node = BookState.book_tree:get_node()

    if node:expand() then
      BookState.book_tree:render()
    end
  end, map_options)

  -- expand all nodes
  Keymap.set(BookState.book_bufnr, "n", "E", expand_all, map_options)

  Keymap.set(BookState.book_bufnr, "n", "st", function()
    BookState.rescan = false
    BookState.search_what = "tag"
    _promptSearchInput(opts)
  end, map_options)
  Keymap.set(BookState.book_bufnr, "n", "rt", function()
    BookState.rescan = true
    BookState.search_what = "tag"
    _promptSearchInput(opts)
  end, map_options)
  Keymap.set(BookState.book_bufnr, "n", "sx", function()
    BookState.rescan = false
    BookState.search_what = "text"
    _promptSearchInput(opts)
  end, map_options)
  Keymap.set(BookState.book_bufnr, "n", "rx", function()
    BookState.rescan = true
    BookState.search_what = "text"
    _promptSearchInput(opts)
  end, map_options)
  Keymap.set(BookState.book_bufnr, "n", "?", function()
    showHelp()
  end, map_options)
end

local TkBookSearch = function(opts)
  opts.prompt = ""
  if inited == false or BookState.book_win == nil then
    opts.prompt = vim.fn.expand("<cword>")
  elseif vim.api.nvim_get_current_win() ~= BookState.book_win then
    opts.prompt = vim.fn.expand("<cword>")
  end

  if inited == false then
    _BookShow(opts)
  end
  BookState.rescan = true
  BookState.search_what = opts.what and opts.what or "tag"
  _promptSearchInput(opts)
end

M.BookShow = function(opts)
  opts = opts or {}
  opts.cwd = M.Cfg.home
  opts.tag_notation = M.Cfg.tag_notation
  local templateDir = Path:new(M.Cfg.templates):make_relative(M.Cfg.home)
  opts.templateDir = templateDir
  opts.rg_pcre = M.Cfg.rg_pcre
  opts.book_use_emoji = M.Cfg.book_use_emoji
  _BookShow(opts)
end

M.BookThis = function(opts)
  if BookState.book_win and BookState.book_bufnr then
    vim.api.nvim_set_current_win(BookState.book_win)
    vim.api.nvim_feedkeys("f", "n", true)
    local linePos = vim.api.nvim_win_get_cursor(BookState.book_win)
    vim.api.nvim_set_current_win(BookState.main_win)
    BookState.main_bufnr = vim.api.nvim_get_current_buf()
    BookState.center_note =
        Pinfo:new({ filepath = vim.fn.expand("%:p"), M.Cfg })
    vim.api.nvim_set_current_win(BookState.book_win)
    BookState.book_tree.nodes = {}
    BookState.book_tree = _revisit()
    expand_all()
    vim.api.nvim_win_set_cursor(0, { BookState.center_note_line, 6 })
    pcall(vim.api.nvim_win_set_cursor, 0, linePos)
  else
    M.BookShow(opts)
  end
end

M.BookSearchTag = function(opts)
  opts = opts or {}
  opts.cwd = M.Cfg.home
  opts.tag_notation = M.Cfg.tag_notation
  local templateDir = Path:new(M.Cfg.templates):make_relative(M.Cfg.home)
  opts.templateDir = templateDir
  opts.rg_pcre = M.Cfg.rg_pcre
  opts.book_use_emoji = M.Cfg.book_use_emoji
  opts.what = "tag"
  TkBookSearch(opts)
end

M.BookSearchText = function(opts)
  opts = opts or {}
  opts.cwd = M.Cfg.home
  opts.tag_notation = M.Cfg.tag_notation
  local templateDir = Path:new(M.Cfg.templates):make_relative(M.Cfg.home)
  opts.templateDir = templateDir
  opts.rg_pcre = M.Cfg.rg_pcre
  opts.book_use_emoji = M.Cfg.book_use_emoji
  opts.what = "text"
  TkBookSearch(opts)
end

Setup()
return M
