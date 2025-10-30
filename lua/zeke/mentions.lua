--[[
  @-Mention Context System for zeke.nvim

  Parses and resolves @-mentions like Claude Code:
  - @file:path/to/file.lua - Include file contents
  - @buffer - Include current buffer
  - @selection - Include visual selection
  - @diag - Include current diagnostics
  - @git:diff - Include git diff

  Usage:
    local mentions = require('zeke.mentions')
    local text = "Can you explain @buffer and fix @diag?"
    local contexts = mentions.parse(text)
    local resolved = mentions.resolve(contexts)
--]]

local M = {}

local api = vim.api
local lsp_context = require('zeke.lsp.context')
local logger = require('zeke.logger')

-- Pattern matching for @-mentions
M.patterns = {
  file = "@file:([^%s]+)",           -- @file:src/init.lua
  buffer = "@buffer",                 -- @buffer
  selection = "@selection",           -- @selection
  diag = "@diag",                     -- @diag (diagnostics)
  git_diff = "@git:diff",             -- @git:diff
  git_status = "@git:status",         -- @git:status
}

---Parse text for @-mentions
---@param text string The text to parse
---@return table List of mention objects {type, value, start_pos, end_pos}
function M.parse(text)
  if not text or text == "" then
    return {}
  end

  local mentions = {}

  -- Parse @file:path mentions
  for match, pos in text:gmatch("()@file:([^%s]+)") do
    table.insert(mentions, {
      type = "file",
      value = match,
      start_pos = pos,
      end_pos = pos + #match + 6, -- "@file:" = 6 chars
      raw = "@file:" .. match,
    })
  end

  -- Parse @buffer
  for pos in text:gmatch("()@buffer") do
    table.insert(mentions, {
      type = "buffer",
      value = nil,
      start_pos = pos,
      end_pos = pos + 7,
      raw = "@buffer",
    })
  end

  -- Parse @selection
  for pos in text:gmatch("()@selection") do
    table.insert(mentions, {
      type = "selection",
      value = nil,
      start_pos = pos,
      end_pos = pos + 10,
      raw = "@selection",
    })
  end

  -- Parse @diag
  for pos in text:gmatch("()@diag") do
    table.insert(mentions, {
      type = "diag",
      value = nil,
      start_pos = pos,
      end_pos = pos + 5,
      raw = "@diag",
    })
  end

  -- Parse @git:diff
  for pos in text:gmatch("()@git:diff") do
    table.insert(mentions, {
      type = "git_diff",
      value = nil,
      start_pos = pos,
      end_pos = pos + 9,
      raw = "@git:diff",
    })
  end

  -- Parse @git:status
  for pos in text:gmatch("()@git:status") do
    table.insert(mentions, {
      type = "git_status",
      value = nil,
      start_pos = pos,
      end_pos = pos + 11,
      raw = "@git:status",
    })
  end

  -- Sort by position
  table.sort(mentions, function(a, b)
    return a.start_pos < b.start_pos
  end)

  logger.debug('mentions', string.format('Parsed %d mentions', #mentions))
  return mentions
end

---Resolve @file mention to content
---@param filepath string Path to file (relative or absolute)
---@return table|nil {content, path, exists}
function M.resolve_file(filepath)
  -- Handle relative paths
  local cwd = vim.fn.getcwd()
  local full_path = filepath

  if not filepath:match("^/") and not filepath:match("^%w:") then
    -- Relative path
    full_path = cwd .. "/" .. filepath
  end

  -- Check if file exists
  if vim.fn.filereadable(full_path) == 0 then
    logger.warn('mentions', 'File not found: ' .. full_path)
    return {
      content = nil,
      path = full_path,
      exists = false,
      error = "File not found",
    }
  end

  -- Read file
  local content = table.concat(vim.fn.readfile(full_path), "\n")

  return {
    content = content,
    path = full_path,
    exists = true,
    lines = vim.fn.readfile(full_path),
  }
end

---Resolve @buffer mention to current buffer content
---@param bufnr number|nil Buffer number (default: current)
---@return table {content, bufnr, name}
function M.resolve_buffer(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")
  local name = api.nvim_buf_get_name(bufnr)

  return {
    content = content,
    bufnr = bufnr,
    name = name,
    lines = lines,
    filetype = api.nvim_buf_get_option(bufnr, 'filetype'),
  }
end

---Resolve @selection mention to visual selection
---@return table|nil {content, start_line, end_line, start_col, end_col}
function M.resolve_selection()
  -- Get visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  if not start_pos or not end_pos then
    logger.warn('mentions', 'No visual selection found')
    return {
      content = nil,
      error = "No visual selection",
    }
  end

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  -- Get lines
  local bufnr = api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  if #lines == 0 then
    return {
      content = nil,
      error = "Empty selection",
    }
  end

  -- Handle single line selection
  if #lines == 1 then
    lines[1] = lines[1]:sub(start_col, end_col)
  else
    -- Multi-line: trim first and last
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
  end

  local content = table.concat(lines, "\n")

  return {
    content = content,
    start_line = start_line,
    end_line = end_line,
    start_col = start_col,
    end_col = end_col,
    lines = lines,
  }
end

---Resolve @diag mention to diagnostics
---@param bufnr number|nil Buffer number (default: current)
---@return table {content, diagnostics, count}
function M.resolve_diagnostics(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local diagnostics = lsp_context.get_diagnostics(bufnr)
  local formatted = lsp_context.format_diagnostics(diagnostics)

  return {
    content = formatted or "No diagnostics found",
    diagnostics = diagnostics,
    count = #diagnostics,
    bufnr = bufnr,
  }
end

---Resolve @git:diff mention to git diff output
---@return table {content, success}
function M.resolve_git_diff()
  -- Run git diff
  local output = vim.fn.system('git diff')
  local success = vim.v.shell_error == 0

  if not success then
    return {
      content = nil,
      success = false,
      error = "Git diff failed: " .. output,
    }
  end

  if output == "" then
    output = "No changes (working directory clean)"
  end

  return {
    content = output,
    success = true,
  }
end

---Resolve @git:status mention to git status output
---@return table {content, success}
function M.resolve_git_status()
  local output = vim.fn.system('git status --short')
  local success = vim.v.shell_error == 0

  if not success then
    return {
      content = nil,
      success = false,
      error = "Git status failed: " .. output,
    }
  end

  if output == "" then
    output = "No changes (working directory clean)"
  end

  return {
    content = output,
    success = true,
  }
end

---Resolve all mentions in a list
---@param mentions table List of mention objects from parse()
---@return table List of resolved contexts {type, raw, resolved_content, metadata}
function M.resolve(mentions)
  local resolved = {}

  for _, mention in ipairs(mentions) do
    local result = {}

    if mention.type == "file" then
      result = M.resolve_file(mention.value)
    elseif mention.type == "buffer" then
      result = M.resolve_buffer()
    elseif mention.type == "selection" then
      result = M.resolve_selection()
    elseif mention.type == "diag" then
      result = M.resolve_diagnostics()
    elseif mention.type == "git_diff" then
      result = M.resolve_git_diff()
    elseif mention.type == "git_status" then
      result = M.resolve_git_status()
    else
      logger.warn('mentions', 'Unknown mention type: ' .. mention.type)
      goto continue
    end

    table.insert(resolved, {
      type = mention.type,
      raw = mention.raw,
      content = result.content,
      metadata = result,
    })

    ::continue::
  end

  return resolved
end

---Format resolved contexts as a prompt addition
---@param resolved table List of resolved contexts
---@return string Formatted context string
function M.format_context(resolved)
  if not resolved or #resolved == 0 then
    return ""
  end

  local parts = { "\n\n--- Context ---\n" }

  for _, ctx in ipairs(resolved) do
    if ctx.content then
      local header = string.format("\n[%s: %s]", ctx.type:upper(), ctx.raw)
      table.insert(parts, header)
      table.insert(parts, "\n```")

      -- Add filetype for syntax highlighting
      if ctx.metadata and ctx.metadata.filetype then
        table.insert(parts, ctx.metadata.filetype)
      elseif ctx.metadata and ctx.metadata.path then
        -- Guess filetype from extension
        local ext = ctx.metadata.path:match("%.([^.]+)$")
        if ext then
          table.insert(parts, ext)
        end
      end

      table.insert(parts, "\n" .. ctx.content)
      table.insert(parts, "\n```\n")
    end
  end

  table.insert(parts, "\n--- End Context ---\n")

  return table.concat(parts, "")
end

---Process text with @-mentions, returning text with context appended
---@param text string Original text with @-mentions
---@return string Processed text with context, table Parsed mentions
function M.process(text)
  local mentions = M.parse(text)

  if #mentions == 0 then
    return text, {}
  end

  local resolved = M.resolve(mentions)
  local context = M.format_context(resolved)

  return text .. context, mentions
end

---Get context chips for UI display
---@param mentions table List of parsed mentions
---@return table List of chip objects {type, label, icon}
function M.get_chips(mentions)
  local chips = {}

  for _, mention in ipairs(mentions) do
    local icon = "📎"
    local label = mention.raw

    if mention.type == "file" then
      icon = "📄"
      -- Shorten path for display
      local short_path = mention.value:match("([^/]+)$") or mention.value
      label = short_path
    elseif mention.type == "buffer" then
      icon = "📝"
      label = "Current Buffer"
    elseif mention.type == "selection" then
      icon = "✂️"
      label = "Selection"
    elseif mention.type == "diag" then
      icon = "🔍"
      label = "Diagnostics"
    elseif mention.type == "git_diff" then
      icon = "🔀"
      label = "Git Diff"
    elseif mention.type == "git_status" then
      icon = "📊"
      label = "Git Status"
    end

    table.insert(chips, {
      type = mention.type,
      label = label,
      icon = icon,
      raw = mention.raw,
    })
  end

  return chips
end

---Show file picker for @file mention completion
---@param callback function Callback with selected file path
function M.show_file_picker(callback)
  -- Use telescope if available, otherwise use vim.ui.select
  local has_telescope, telescope_builtin = pcall(require, 'telescope.builtin')

  if has_telescope then
    telescope_builtin.find_files({
      prompt_title = "@file: Select File",
      attach_mappings = function(_, map)
        local actions = require('telescope.actions')
        local action_state = require('telescope.actions.state')

        map('i', '<CR>', function(bufnr)
          local selection = action_state.get_selected_entry()
          actions.close(bufnr)

          if selection and callback then
            callback(selection.value or selection[1])
          end
        end)

        return true
      end,
    })
  else
    -- Fallback: use vim.ui.select with file list
    local files = vim.fn.glob('**/*', false, true)

    -- Filter out directories
    files = vim.tbl_filter(function(f)
      return vim.fn.isdirectory(f) == 0
    end, files)

    vim.ui.select(files, {
      prompt = "@file: Select File",
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if choice and callback then
        callback(choice)
      end
    end)
  end
end

return M
