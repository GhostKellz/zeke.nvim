--[[
  Enhanced Code Actions Menu for zeke.nvim

  Context-aware quick actions that automatically include relevant context:
  - Explain, Fix, Refactor, Test, Document, Optimize, etc.
  - Automatically detects: selection, diagnostics, symbols, git changes
  - Smart prompts based on filetype and LSP info
--]]

local M = {}

local api = vim.api
local cli = require('zeke.cli')
local lsp_context = require('zeke.lsp.context')
local mentions = require('zeke.mentions')
local logger = require('zeke.logger')

-- Action definitions with smart context
M.actions = {
  {
    id = "explain",
    label = "🔍 Explain Code",
    description = "Explain what this code does",
    prompt = function(ctx)
      if ctx.selection then
        return "Explain what this code does:\n\n" .. ctx.selection_text
      elseif ctx.symbol then
        return string.format("Explain the %s '%s' in @buffer", ctx.symbol.kind, ctx.symbol.name)
      else
        return "Explain @buffer"
      end
    end,
    needs_context = true,
  },

  {
    id = "fix",
    label = "🔧 Fix Issues",
    description = "Fix errors and warnings",
    prompt = function(ctx)
      if ctx.diagnostics and #ctx.diagnostics > 0 then
        return "Fix these issues:\n\n@diag\n\nHere's the code:\n\n" .. (ctx.selection_text or "@buffer")
      else
        return "Review and fix any potential issues in:\n\n" .. (ctx.selection_text or "@buffer")
      end
    end,
    needs_context = true,
    condition = function(ctx)
      -- Always show, but prioritize if there are diagnostics
      return true
    end,
  },

  {
    id = "refactor",
    label = "♻️ Refactor",
    description = "Improve code structure and readability",
    prompt = function(ctx)
      if ctx.selection then
        return "Refactor this code to be cleaner and more maintainable:\n\n" .. ctx.selection_text
      else
        return "Suggest refactoring improvements for @buffer"
      end
    end,
    needs_context = true,
  },

  {
    id = "test",
    label = "🧪 Generate Tests",
    description = "Generate unit tests",
    prompt = function(ctx)
      if ctx.selection then
        return string.format(
          "Generate comprehensive unit tests for this code (language: %s):\n\n%s",
          ctx.filetype,
          ctx.selection_text
        )
      elseif ctx.symbol and (ctx.symbol.kind == "Function" or ctx.symbol.kind == "Method") then
        return string.format("Generate unit tests for the function '%s' in @buffer", ctx.symbol.name)
      else
        return "Generate unit tests for @buffer"
      end
    end,
    needs_context = true,
  },

  {
    id = "document",
    label = "📝 Add Documentation",
    description = "Add docstrings and comments",
    prompt = function(ctx)
      if ctx.selection then
        return string.format(
          "Add comprehensive documentation comments (docstrings) for this code (language: %s):\n\n%s",
          ctx.filetype,
          ctx.selection_text
        )
      else
        return "Add documentation comments to all functions and types in @buffer"
      end
    end,
    needs_context = true,
  },

  {
    id = "optimize",
    label = "⚡ Optimize Performance",
    description = "Improve code performance",
    prompt = function(ctx)
      if ctx.selection then
        return "Analyze and optimize the performance of this code:\n\n" .. ctx.selection_text
      else
        return "Analyze @buffer for performance improvements and suggest optimizations"
      end
    end,
    needs_context = true,
  },

  {
    id = "security",
    label = "🔒 Security Review",
    description = "Check for security vulnerabilities",
    prompt = function(ctx)
      if ctx.selection then
        return "Review this code for security vulnerabilities:\n\n" .. ctx.selection_text
      else
        return "Perform a security review of @buffer and identify potential vulnerabilities"
      end
    end,
    needs_context = true,
  },

  {
    id = "simplify",
    label = "✨ Simplify",
    description = "Make code simpler and clearer",
    prompt = function(ctx)
      if ctx.selection then
        return "Simplify this code while maintaining functionality:\n\n" .. ctx.selection_text
      else
        return "Simplify @buffer to make it more readable and maintainable"
      end
    end,
    needs_context = true,
  },

  {
    id = "review",
    label = "👀 Code Review",
    description = "Comprehensive code review",
    prompt = function(ctx)
      local parts = { "Perform a comprehensive code review covering:" }
      table.insert(parts, "- Code quality and style")
      table.insert(parts, "- Potential bugs")
      table.insert(parts, "- Performance issues")
      table.insert(parts, "- Security concerns")
      table.insert(parts, "- Best practices")
      table.insert(parts, "")

      if ctx.selection then
        table.insert(parts, "Code:\n" .. ctx.selection_text)
      else
        table.insert(parts, "@buffer")
      end

      return table.concat(parts, "\n")
    end,
    needs_context = true,
  },

  {
    id = "commit_msg",
    label = "📋 Generate Commit Message",
    description = "Create git commit message",
    prompt = function(ctx)
      return "Generate a detailed git commit message for these changes:\n\n@git:diff"
    end,
    needs_context = false,
    condition = function(ctx)
      -- Only show if we're in a git repo
      return ctx.in_git_repo
    end,
  },

  {
    id = "convert",
    label = "🔄 Convert Code",
    description = "Convert to another language/format",
    prompt = function(ctx)
      if ctx.selection then
        return string.format(
          "Convert this %s code to [specify target language]:\n\n%s",
          ctx.filetype,
          ctx.selection_text
        )
      else
        return "Convert @buffer to [specify target language]"
      end
    end,
    needs_context = true,
  },

  {
    id = "custom",
    label = "💭 Custom Action",
    description = "Enter a custom prompt",
    prompt = function(ctx)
      -- Will prompt user for input
      return nil
    end,
    needs_context = false,
    custom_input = true,
  },
}

---Gather context for actions
---@return table Context object
function M.gather_context()
  local ctx = {
    bufnr = api.nvim_get_current_buf(),
    winnr = api.nvim_get_current_win(),
    filename = api.nvim_buf_get_name(0),
    filetype = api.nvim_buf_get_option(0, 'filetype'),
    cursor = api.nvim_win_get_cursor(0),
  }

  -- Check for selection
  local mode = api.nvim_get_mode().mode
  if mode:match('[vV]') then
    ctx.selection = true
    local selection = mentions.resolve_selection()
    if selection and selection.content then
      ctx.selection_text = selection.content
      ctx.selection_range = {
        start_line = selection.start_line,
        end_line = selection.end_line,
      }
    end
  end

  -- Get diagnostics
  ctx.diagnostics = lsp_context.get_diagnostics(ctx.bufnr)

  -- Get symbol at cursor
  local params = vim.lsp.util.make_position_params()
  local result = vim.lsp.buf_request_sync(0, 'textDocument/documentSymbol', {
    textDocument = params.textDocument
  }, 1000)

  if result and not vim.tbl_isempty(result) then
    for _, res in pairs(result) do
      if res.result then
        -- Find symbol at cursor position
        ctx.symbol = M.find_symbol_at_cursor(res.result, ctx.cursor[1])
        break
      end
    end
  end

  -- Check if in git repo
  local git_check = vim.fn.system('git rev-parse --git-dir 2>/dev/null')
  ctx.in_git_repo = vim.v.shell_error == 0

  -- Get git status if in repo
  if ctx.in_git_repo then
    local git_status = vim.fn.system('git status --porcelain')
    ctx.has_git_changes = git_status ~= ""
  end

  return ctx
end

---Find symbol at cursor position
---@param symbols table LSP symbols
---@param line number Line number (1-indexed)
---@return table|nil Symbol info
function M.find_symbol_at_cursor(symbols, line)
  for _, symbol in ipairs(symbols) do
    local range = symbol.range or symbol.location and symbol.location.range
    if range then
      local start_line = range.start.line + 1
      local end_line = range['end'].line + 1

      if line >= start_line and line <= end_line then
        return {
          name = symbol.name,
          kind = vim.lsp.protocol.SymbolKind[symbol.kind] or "Unknown",
        }
      end
    end

    -- Check children recursively
    if symbol.children then
      local child_symbol = M.find_symbol_at_cursor(symbol.children, line)
      if child_symbol then
        return child_symbol
      end
    end
  end

  return nil
end

---Filter actions based on context
---@param actions table List of actions
---@param ctx table Context object
---@return table Filtered actions
function M.filter_actions(actions, ctx)
  local filtered = {}

  for _, action in ipairs(actions) do
    local should_show = true

    -- Check condition function if it exists
    if action.condition then
      should_show = action.condition(ctx)
    end

    if should_show then
      table.insert(filtered, action)
    end
  end

  return filtered
end

---Execute an action
---@param action table Action object
---@param ctx table Context object
function M.execute_action(action, ctx)
  logger.info('actions', 'Executing action: ' .. action.id)

  -- Get prompt
  local prompt
  if action.custom_input then
    -- Prompt user for custom input
    vim.ui.input({
      prompt = 'Enter your prompt: ',
      default = ctx.selection and ctx.selection_text or '',
    }, function(input)
      if not input or input == "" then
        return
      end

      -- Add context if selection
      if ctx.selection then
        prompt = input .. "\n\n```" .. ctx.filetype .. "\n" .. ctx.selection_text .. "\n```"
      else
        prompt = input
      end

      M.send_to_agent(prompt)
    end)
    return
  else
    prompt = action.prompt(ctx)
  end

  if not prompt then
    vim.notify("No prompt generated", vim.log.levels.WARN)
    return
  end

  -- Process @-mentions in prompt
  local processed_prompt, _ = mentions.process(prompt)

  -- Send to agent or CLI
  M.send_to_agent(processed_prompt)
end

---Send prompt to agent or open agent with prompt
---@param prompt string The prompt to send
function M.send_to_agent(prompt)
  -- Try to use agent if available
  local has_agent, agent = pcall(require, 'zeke.agent')

  if has_agent and agent.state.chat_winnr and api.nvim_win_is_valid(agent.state.chat_winnr) then
    -- Agent is open, add prompt to input buffer
    if agent.state.input_bufnr and api.nvim_buf_is_valid(agent.state.input_bufnr) then
      api.nvim_buf_set_lines(agent.state.input_bufnr, 0, -1, false, vim.split(prompt, '\n'))
      api.nvim_set_current_win(agent.state.input_winnr)
      vim.cmd('startinsert')
    end
  else
    -- Agent not open, use CLI directly or open agent
    local choice = vim.fn.confirm(
      "Send to:",
      "&Agent Interface\n&CLI Chat\n&Cancel",
      1
    )

    if choice == 1 then
      -- Open agent with prompt
      if has_agent then
        agent.open()
        vim.defer_fn(function()
          if agent.state.input_bufnr and api.nvim_buf_is_valid(agent.state.input_bufnr) then
            api.nvim_buf_set_lines(agent.state.input_bufnr, 0, -1, false, vim.split(prompt, '\n'))
          end
        end, 100)
      end
    elseif choice == 2 then
      -- Use CLI directly
      cli.chat(prompt)
    end
  end
end

---Show action picker
function M.show_picker()
  local ctx = M.gather_context()
  local actions = M.filter_actions(M.actions, ctx)

  -- Build picker items
  local items = {}
  for _, action in ipairs(actions) do
    table.insert(items, {
      text = action.label,
      description = action.description,
      action = action,
    })
  end

  -- Use telescope if available, otherwise vim.ui.select
  local has_telescope, telescope = pcall(require, 'telescope')

  if has_telescope then
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions_telescope = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    pickers.new({}, {
      prompt_title = '✨ Zeke Code Actions',
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item,
            display = item.text .. ' - ' .. item.description,
            ordinal = item.text .. ' ' .. item.description,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions_telescope.select_default:replace(function()
          actions_telescope.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()

          if selection and selection.value then
            M.execute_action(selection.value.action, ctx)
          end
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select
    local display_items = {}
    for _, item in ipairs(items) do
      table.insert(display_items, item.text .. ' - ' .. item.description)
    end

    vim.ui.select(display_items, {
      prompt = '✨ Zeke Code Actions:',
      format_item = function(item)
        return item
      end,
    }, function(choice, idx)
      if choice and idx then
        M.execute_action(items[idx].action, ctx)
      end
    end)
  end
end

return M
