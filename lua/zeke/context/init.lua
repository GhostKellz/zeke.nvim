-- Context aggregation and formatting for AI requests
local M = {}

local tools = require('zeke.context.tools')
local logger = require('zeke.logger')

-- Build context from various sources
function M.build_context(opts)
  opts = opts or {}
  local context = {}

  logger.debug('context', 'Building context with options: ' .. vim.inspect(opts))

  if opts.include_buffer then
    context.current_file = tools.get_current_file()
    if context.current_file then
      logger.debug('context', 'Included current buffer: ' .. context.current_file.path)
    end
  end

  if opts.include_selection then
    context.selection = tools.get_current_selection()
    if context.selection and not context.selection.isEmpty then
      logger.debug('context', string.format('Included selection: lines %d-%d',
        context.selection.start_line, context.selection.end_line))
    end
  end

  if opts.include_diagnostics then
    context.diagnostics = tools.get_diagnostics()
    if context.diagnostics then
      logger.debug('context', string.format('Included %d diagnostics', #context.diagnostics))
    end
  end

  if opts.include_workspace then
    context.workspace = tools.get_workspace_folders()
    if context.workspace then
      logger.debug('context', 'Included workspace folders')
    end
  end

  if opts.include_open_files then
    context.open_files = tools.get_open_editors()
    if context.open_files then
      logger.debug('context', string.format('Included %d open files', #context.open_files))
    end
  end

  return context
end

-- Format context for HTTP request (as markdown for AI prompt)
function M.format_for_request(context)
  local parts = {}

  -- Current file
  if context.current_file then
    local file = context.current_file
    table.insert(parts, string.format("**Current File**: `%s` (%d lines, %s)%s\n```%s\n%s\n```",
      file.path,
      file.line_count,
      file.language or "unknown",
      file.is_modified and " [modified]" or "",
      file.language or "",
      file.content))
  end

  -- Selection
  if context.selection and context.selection.text ~= "" and not context.selection.isEmpty then
    table.insert(parts, string.format("**Selected Text** (lines %d-%d from `%s`):\n```\n%s\n```",
      context.selection.start_line,
      context.selection.end_line,
      context.selection.filePath,
      context.selection.text))
  end

  -- Diagnostics
  if context.diagnostics and #context.diagnostics > 0 then
    local diag_lines = {}
    for _, d in ipairs(context.diagnostics) do
      table.insert(diag_lines, string.format("- Line %d, Col %d: [%s] %s%s",
        d.line,
        d.column,
        d.severity,
        d.message,
        d.source and " (" .. d.source .. ")" or ""))
    end
    table.insert(parts, "**Diagnostics** (" .. #context.diagnostics .. " issues):\n" .. table.concat(diag_lines, "\n"))
  end

  -- Workspace
  if context.workspace and #context.workspace > 0 then
    local ws_lines = {}
    for _, ws in ipairs(context.workspace) do
      table.insert(ws_lines, string.format("- %s: `%s`", ws.name, ws.path))
    end
    table.insert(parts, "**Workspace**:\n" .. table.concat(ws_lines, "\n"))
  end

  -- Open files
  if context.open_files and #context.open_files > 0 then
    local file_lines = {}
    for _, file in ipairs(context.open_files) do
      table.insert(file_lines, string.format("- `%s` (%d lines, %s)%s",
        file.path,
        file.line_count,
        file.language or "unknown",
        file.is_modified and " [modified]" or ""))
    end
    table.insert(parts, "**Open Files** (" .. #context.open_files .. " files):\n" .. table.concat(file_lines, "\n"))
  end

  local formatted = table.concat(parts, "\n\n")
  logger.debug('context', 'Formatted context: ' .. #formatted .. ' characters')

  return formatted
end

-- Build and format context in one step
function M.get_formatted_context(opts)
  local context = M.build_context(opts)
  return M.format_for_request(context)
end

return M
