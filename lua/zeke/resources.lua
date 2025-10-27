-- Resource parsing system for injecting context into prompts
-- Supports: #file:path, #buffer, #selection, #diagnostics, #gitdiff

local M = {}

local tools = require('zeke.context.tools')
local logger = require('zeke.logger')

-- Parse resources from a message
-- Returns: resources table, cleaned message
function M.parse(message)
  local resources = {}
  local clean_message = message

  logger.debug('resources', 'Parsing resources from message: ' .. message:sub(1, 100))

  -- Match #file:path (with quotes or without)
  for path in message:gmatch('#file:"([^"]+)"') do
    local content = M.get_file_content(path)
    if content then
      table.insert(resources, {
        type = "file",
        path = path,
        content = content,
      })
      clean_message = clean_message:gsub('#file:"' .. path:gsub('([%.%-%+%[%]%(%)%$%^%%%?%*])', '%%%1') .. '"', '')
      logger.debug('resources', 'Added file resource (quoted): ' .. path)
    end
  end

  -- Match unquoted #file:path (no spaces)
  for path in message:gmatch('#file:([%w/._-]+)') do
    if not resources[path] then  -- Avoid duplicates
      local content = M.get_file_content(path)
      if content then
        table.insert(resources, {
          type = "file",
          path = path,
          content = content,
        })
        clean_message = clean_message:gsub('#file:' .. path:gsub('([%.%-%+%[%]%(%)%$%^%%%?%*])', '%%%1'), '')
        logger.debug('resources', 'Added file resource: ' .. path)
      end
    end
  end

  -- Match #buffer (current buffer)
  if message:match('#buffer') then
    local file = tools.get_current_file()
    if file then
      table.insert(resources, {
        type = "buffer",
        path = file.path,
        content = file.content,
        language = file.language,
      })
      clean_message = clean_message:gsub('#buffer', '')
      logger.debug('resources', 'Added buffer resource: ' .. file.path)
    end
  end

  -- Match #selection (current or latest selection)
  if message:match('#selection') then
    local selection = tools.get_latest_selection()
    if selection and not selection.isEmpty then
      table.insert(resources, {
        type = "selection",
        text = selection.text,
        start_line = selection.start_line,
        end_line = selection.end_line,
        file_path = selection.filePath,
      })
      clean_message = clean_message:gsub('#selection', '')
      logger.debug('resources', string.format('Added selection resource: lines %d-%d', selection.start_line, selection.end_line))
    end
  end

  -- Match #diagnostics
  if message:match('#diagnostics') then
    local diags = tools.get_diagnostics()
    if #diags > 0 then
      table.insert(resources, {
        type = "diagnostics",
        diagnostics = diags,
      })
      clean_message = clean_message:gsub('#diagnostics', '')
      logger.debug('resources', string.format('Added diagnostics resource: %d issues', #diags))
    end
  end

  -- Match #gitdiff (staged changes)
  if message:match('#gitdiff') then
    local diff = vim.fn.system("git diff --cached")
    if vim.v.shell_error == 0 and diff ~= "" then
      table.insert(resources, {
        type = "gitdiff",
        content = diff,
      })
      clean_message = clean_message:gsub('#gitdiff', '')
      logger.debug('resources', 'Added gitdiff resource')
    end
  end

  -- Match #git (unstaged changes)
  if message:match('#git[^d]') or message:match('#git$') then
    local diff = vim.fn.system("git diff")
    if vim.v.shell_error == 0 and diff ~= "" then
      table.insert(resources, {
        type = "git",
        content = diff,
      })
      clean_message = clean_message:gsub('#git([^d])', '%1')
      clean_message = clean_message:gsub('#git$', '')
      logger.debug('resources', 'Added git resource')
    end
  end

  -- Match #open (list of open files)
  if message:match('#open') then
    local open_files = tools.get_open_editors()
    if #open_files > 0 then
      table.insert(resources, {
        type = "open_files",
        files = open_files,
      })
      clean_message = clean_message:gsub('#open', '')
      logger.debug('resources', string.format('Added open files resource: %d files', #open_files))
    end
  end

  logger.info('resources', string.format('Parsed %d resources', #resources))
  return resources, vim.trim(clean_message)
end

-- Inject resources into message as formatted context
function M.inject_into_message(message, resources)
  if #resources == 0 then
    return message
  end

  local context_parts = {}

  for _, res in ipairs(resources) do
    if res.type == "file" or res.type == "buffer" then
      local type_label = res.type == "file" and "File" or "Current Buffer"
      local lang_str = res.language and res.language or ""
      table.insert(context_parts, string.format(
        "**%s**: `%s`\n```%s\n%s\n```",
        type_label,
        res.path,
        lang_str,
        res.content
      ))
    elseif res.type == "selection" then
      table.insert(context_parts, string.format(
        "**Selected Text** (lines %d-%d from `%s`):\n```\n%s\n```",
        res.start_line,
        res.end_line,
        res.file_path,
        res.text
      ))
    elseif res.type == "diagnostics" then
      local diag_lines = {}
      for _, d in ipairs(res.diagnostics) do
        table.insert(diag_lines, string.format("- Line %d, Col %d: [%s] %s%s",
          d.line,
          d.column,
          d.severity,
          d.message,
          d.source and " (" .. d.source .. ")" or ""))
      end
      table.insert(context_parts, "**Diagnostics** (" .. #res.diagnostics .. " issues):\n" .. table.concat(diag_lines, "\n"))
    elseif res.type == "gitdiff" then
      table.insert(context_parts, "**Git Diff** (staged changes):\n```diff\n" .. res.content .. "\n```")
    elseif res.type == "git" then
      table.insert(context_parts, "**Git Diff** (unstaged changes):\n```diff\n" .. res.content .. "\n```")
    elseif res.type == "open_files" then
      local file_lines = {}
      for _, file in ipairs(res.files) do
        table.insert(file_lines, string.format("- `%s` (%d lines, %s)%s",
          file.path,
          file.line_count,
          file.language or "unknown",
          file.is_modified and " [modified]" or ""))
      end
      table.insert(context_parts, "**Open Files** (" .. #res.files .. " files):\n" .. table.concat(file_lines, "\n"))
    end
  end

  -- Prepend context to message
  local enhanced = table.concat(context_parts, "\n\n") .. "\n\n---\n\n" .. message
  logger.debug('resources', string.format('Enhanced message: %d -> %d characters', #message, #enhanced))

  return enhanced
end

-- Get file content
function M.get_file_content(path)
  path = vim.fn.expand(path)

  -- Check if file is readable
  if vim.fn.filereadable(path) == 0 then
    logger.warn('resources', 'File not readable: ' .. path)
    return nil
  end

  -- Try to read file
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    logger.warn('resources', 'Failed to read file: ' .. path)
    return nil
  end

  return table.concat(lines, '\n')
end

-- Parse and inject in one step
function M.process_message(message)
  local resources, clean_message = M.parse(message)
  return M.inject_into_message(clean_message, resources)
end

return M
