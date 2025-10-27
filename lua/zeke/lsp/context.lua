-- LSP context integration for intelligent code assistance
-- Provides diagnostics, symbols, and context-aware suggestions

local M = {}

local api = vim.api
local cli = require('zeke.cli')
local logger = require('zeke.logger')

-- Get diagnostics for current buffer or line
function M.get_diagnostics(bufnr, line_num)
  bufnr = bufnr or api.nvim_get_current_buf()

  local diagnostics = vim.diagnostic.get(bufnr)

  if line_num then
    -- Filter to specific line
    diagnostics = vim.tbl_filter(function(diag)
      return diag.lnum + 1 == line_num
    end, diagnostics)
  end

  return diagnostics
end

-- Format diagnostics as human-readable text
function M.format_diagnostics(diagnostics)
  if not diagnostics or #diagnostics == 0 then
    return nil
  end

  local lines = { "Diagnostics:" }

  for _, diag in ipairs(diagnostics) do
    local severity = ({
      [vim.diagnostic.severity.ERROR] = "ERROR",
      [vim.diagnostic.severity.WARN] = "WARN",
      [vim.diagnostic.severity.INFO] = "INFO",
      [vim.diagnostic.severity.HINT] = "HINT",
    })[diag.severity] or "UNKNOWN"

    local msg = string.format(
      "  [%s] Line %d: %s",
      severity,
      diag.lnum + 1,
      diag.message
    )

    if diag.source then
      msg = msg .. string.format(" (source: %s)", diag.source)
    end

    table.insert(lines, msg)
  end

  return table.concat(lines, "\n")
end

-- Get hover information at cursor
function M.get_hover_info()
  local params = vim.lsp.util.make_position_params()
  local result = vim.lsp.buf_request_sync(0, 'textDocument/hover', params, 1000)

  if not result or vim.tbl_isempty(result) then
    return nil
  end

  -- Extract hover content from first response
  for _, res in pairs(result) do
    if res.result and res.result.contents then
      local contents = res.result.contents
      if type(contents) == 'string' then
        return contents
      elseif contents.value then
        return contents.value
      elseif type(contents) == 'table' and contents[1] then
        if type(contents[1]) == 'string' then
          return contents[1]
        elseif contents[1].value then
          return contents[1].value
        end
      end
    end
  end

  return nil
end

-- Get document symbols (outline)
function M.get_symbols(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local result = vim.lsp.buf_request_sync(bufnr, 'textDocument/documentSymbol', params, 1000)

  if not result or vim.tbl_isempty(result) then
    return nil
  end

  for _, res in pairs(result) do
    if res.result then
      return res.result
    end
  end

  return nil
end

-- Format symbols as text outline
function M.format_symbols(symbols, indent)
  if not symbols or #symbols == 0 then
    return nil
  end

  indent = indent or 0
  local lines = {}

  for _, symbol in ipairs(symbols) do
    local prefix = string.rep("  ", indent)
    local kind = vim.lsp.protocol.SymbolKind[symbol.kind] or "Unknown"

    table.insert(lines, string.format("%s%s [%s]", prefix, symbol.name, kind))

    if symbol.children and #symbol.children > 0 then
      local child_lines = M.format_symbols(symbol.children, indent + 1)
      if child_lines then
        table.insert(lines, child_lines)
      end
    end
  end

  return table.concat(lines, "\n")
end

-- Get full context for current buffer/position
function M.get_full_context(opts)
  opts = opts or {}

  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  local context = {
    filename = api.nvim_buf_get_name(bufnr),
    filetype = api.nvim_buf_get_option(bufnr, 'filetype'),
    line_number = line_num,
  }

  -- Get diagnostics
  if opts.include_diagnostics ~= false then
    local diags = M.get_diagnostics(bufnr)
    if diags and #diags > 0 then
      context.diagnostics = M.format_diagnostics(diags)
    end
  end

  -- Get current line diagnostics
  if opts.include_line_diagnostics then
    local line_diags = M.get_diagnostics(bufnr, line_num)
    if line_diags and #line_diags > 0 then
      context.line_diagnostics = M.format_diagnostics(line_diags)
    end
  end

  -- Get hover info
  if opts.include_hover then
    local hover = M.get_hover_info()
    if hover then
      context.hover = hover
    end
  end

  -- Get symbols
  if opts.include_symbols then
    local symbols = M.get_symbols(bufnr)
    if symbols then
      context.symbols = M.format_symbols(symbols)
    end
  end

  -- Get buffer content
  if opts.include_buffer then
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    context.content = table.concat(lines, "\n")
  end

  -- Get surrounding context (lines around cursor)
  if opts.context_lines then
    local start_line = math.max(0, line_num - opts.context_lines - 1)
    local end_line = math.min(api.nvim_buf_line_count(bufnr), line_num + opts.context_lines)
    local lines = api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
    context.surrounding = table.concat(lines, "\n")
  end

  return context
end

-- Format context as prompt text
function M.format_context_prompt(context)
  local parts = {}

  if context.filename then
    table.insert(parts, string.format("File: %s", context.filename))
  end

  if context.filetype then
    table.insert(parts, string.format("Language: %s", context.filetype))
  end

  if context.line_number then
    table.insert(parts, string.format("Line: %d", context.line_number))
  end

  if context.diagnostics then
    table.insert(parts, "\n" .. context.diagnostics)
  end

  if context.line_diagnostics then
    table.insert(parts, "\nCurrent Line Issues:")
    table.insert(parts, context.line_diagnostics)
  end

  if context.hover then
    table.insert(parts, "\nSymbol Info:")
    table.insert(parts, context.hover)
  end

  if context.symbols then
    table.insert(parts, "\nDocument Outline:")
    table.insert(parts, context.symbols)
  end

  if context.surrounding then
    table.insert(parts, "\nCode Context:")
    table.insert(parts, "```" .. (context.filetype or ""))
    table.insert(parts, context.surrounding)
    table.insert(parts, "```")
  end

  if context.content then
    table.insert(parts, "\nFull Buffer:")
    table.insert(parts, "```" .. (context.filetype or ""))
    table.insert(parts, context.content)
    table.insert(parts, "```")
  end

  return table.concat(parts, "\n")
end

-- Auto-fix diagnostic at cursor
function M.fix_diagnostic_at_cursor()
  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  -- Get diagnostics at current line
  local diags = M.get_diagnostics(bufnr, line_num)

  if not diags or #diags == 0 then
    vim.notify("No diagnostics found at cursor", vim.log.levels.INFO)
    return
  end

  -- Get context
  local context = M.get_full_context({
    include_diagnostics = true,
    include_line_diagnostics = true,
    context_lines = 10,
  })

  -- Build fix prompt
  local prompt = M.format_context_prompt(context)
  prompt = prompt .. "\n\nPlease provide a fix for the diagnostic issue on this line. Return ONLY the corrected code for the affected area."

  -- Request fix from Zeke
  vim.notify("Requesting fix from Zeke...", vim.log.levels.INFO)

  local fix_text = ''
  cli.stream_chat(prompt,
    function(chunk)
      fix_text = fix_text .. chunk
    end,
    function(full_response, exit_code)
      vim.schedule(function()
        if exit_code == 0 and full_response ~= '' then
          -- Show fix in diff view
          local diff = require('zeke.diff')
          local current_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

          -- Extract code from response
          local code = full_response:match('```[%w]*\n(.-)```') or full_response

          -- Show diff and ask user to apply
          vim.notify("Fix generated. Review the suggested changes.", vim.log.levels.INFO)

          -- TODO: Show in diff view and allow user to accept/reject
          -- For now, just notify
          print("Suggested fix:")
          print(code)
        else
          vim.notify("Failed to generate fix", vim.log.levels.ERROR)
        end
      end)
    end
  )
end

-- Explain diagnostic
function M.explain_diagnostic_at_cursor()
  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  local diags = M.get_diagnostics(bufnr, line_num)

  if not diags or #diags == 0 then
    vim.notify("No diagnostics found at cursor", vim.log.levels.INFO)
    return
  end

  local context = M.get_full_context({
    include_line_diagnostics = true,
    context_lines = 5,
  })

  local prompt = M.format_context_prompt(context)
  prompt = prompt .. "\n\nPlease explain what this diagnostic means and how to fix it."

  -- Show explanation in floating window
  vim.notify("Asking Zeke to explain...", vim.log.levels.INFO)

  local explanation = ''
  cli.stream_chat(prompt,
    function(chunk)
      explanation = explanation .. chunk
    end,
    function(full_response, exit_code)
      vim.schedule(function()
        if exit_code == 0 then
          -- Show in floating window
          local lines = vim.split(full_response, '\n')
          local buf = api.nvim_create_buf(false, true)
          api.nvim_buf_set_lines(buf, 0, -1, false, lines)
          api.nvim_buf_set_option(buf, 'filetype', 'markdown')

          local width = math.min(80, vim.o.columns - 4)
          local height = math.min(#lines + 2, vim.o.lines - 4)

          local win = api.nvim_open_win(buf, true, {
            relative = 'cursor',
            width = width,
            height = height,
            row = 1,
            col = 0,
            style = 'minimal',
            border = 'rounded',
            title = ' Diagnostic Explanation ',
            title_pos = 'center',
          })

          api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<cr>', { silent = true })
          api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>close<cr>', { silent = true })
        end
      end)
    end
  )
end

return M
