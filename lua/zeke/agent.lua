--[[
  zeke.nvim Agent Interface (:ZekeCode)

  Main AI agent interface inspired by Claude Code.
  Features:
  - Agent-style conversational chat
  - Model cycling with Tab
  - Context-aware commands
  - Persistent chat history
  - Streaming responses
--]]

local M = {}

local cli = require('zeke.cli')
local models = require('zeke.models')
local logger = require('zeke.logger')
local config = require('zeke.config')
local mentions = require('zeke.mentions')
local context_chips = require('zeke.ui.context_chips')
local tokens = require('zeke.tokens')
local safety = require('zeke.safety')
local progress = require('zeke.progress')

-- Agent state
M.state = {
  chat_bufnr = nil,
  chat_winnr = nil,
  input_bufnr = nil,
  input_winnr = nil,
  current_job = nil,  -- For streaming
  conversation_history = {},
}

-- Create or get chat buffer
local function get_or_create_chat_buffer()
  if M.state.chat_bufnr and vim.api.nvim_buf_is_valid(M.state.chat_bufnr) then
    return M.state.chat_bufnr
  end

  -- Create new buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
  vim.api.nvim_set_option_value('wrap', true, { buf = bufnr })
  vim.api.nvim_set_option_value('linebreak', true, { buf = bufnr })
  vim.api.nvim_buf_set_name(bufnr, 'ZekeCode Chat')

  M.state.chat_bufnr = bufnr
  return bufnr
end

-- Create or get input buffer
local function get_or_create_input_buffer()
  if M.state.input_bufnr and vim.api.nvim_buf_is_valid(M.state.input_bufnr) then
    return M.state.input_bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
  vim.api.nvim_buf_set_name(bufnr, 'ZekeCode Input')

  M.state.input_bufnr = bufnr
  return bufnr
end

-- Append message to chat
local function append_to_chat(message, role)
  local bufnr = get_or_create_chat_buffer()

  -- Format message
  local prefix = role == "user" and "👤 You" or "🤖 Zeke"
  local current_model = models.get_current()
  if role == "assistant" and current_model then
    prefix = string.format("%s %s", current_model.icon or "🤖", current_model.name)
  end

  local lines = {
    "",
    "---",
    prefix,
    "",
  }

  -- Split message into lines
  for line in message:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  table.insert(lines, "")

  -- Append to buffer
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, line_count, -1, false, lines)

  -- Scroll to bottom if window is visible
  if M.state.chat_winnr and vim.api.nvim_win_is_valid(M.state.chat_winnr) then
    vim.api.nvim_win_set_cursor(M.state.chat_winnr, { vim.api.nvim_buf_line_count(bufnr), 0 })
  end
end

-- Show model info in statusline format
local function get_statusline()
  local current_model = models.get_current()
  if not current_model then
    return "ZekeCode - No Model"
  end

  return string.format(
    "ZekeCode - %s %s | %dk tokens | Tab to cycle",
    current_model.icon or "",
    current_model.name,
    math.floor(current_model.context_window / 1000)
  )
end

-- Setup keymaps for agent interface
local function setup_agent_keymaps(chat_bufnr, input_bufnr)
  local opts = { buffer = input_bufnr, silent = true }

  -- <CR> in input buffer sends message
  vim.keymap.set('n', '<CR>', function()
    M.send_message()
  end, opts)

  vim.keymap.set('i', '<C-CR>', function()
    M.send_message()
    vim.cmd('startinsert')
  end, opts)

  -- Tab/S-Tab to cycle models
  vim.keymap.set('n', '<Tab>', function()
    local model = models.cycle_next()
    vim.notify(string.format("Model: %s %s", model.icon, model.name), vim.log.levels.INFO)
    -- Update statusline
    if M.state.chat_winnr and vim.api.nvim_win_is_valid(M.state.chat_winnr) then
      vim.api.nvim_set_option_value('statusline', get_statusline(), { win = M.state.chat_winnr })
    end
  end, opts)

  vim.keymap.set('n', '<S-Tab>', function()
    local model = models.cycle_prev()
    vim.notify(string.format("Model: %s %s", model.icon, model.name), vim.log.levels.INFO)
    if M.state.chat_winnr and vim.api.nvim_win_is_valid(M.state.chat_winnr) then
      vim.api.nvim_set_option_value('statusline', get_statusline(), { win = M.state.chat_winnr })
    end
  end, opts)

  -- Model picker
  vim.keymap.set('n', '<leader>m', function()
    models.show_picker()
  end, opts)

  -- Escape to close
  vim.keymap.set('n', '<Esc>', function()
    M.close()
  end, { buffer = input_bufnr, silent = true })

  vim.keymap.set('n', '<Esc>', function()
    M.close()
  end, { buffer = chat_bufnr, silent = true })

  -- Clear chat
  vim.keymap.set('n', '<C-l>', function()
    M.clear_chat()
  end, opts)

  -- @file picker (Ctrl+F in insert mode)
  vim.keymap.set('i', '<C-f>', function()
    mentions.show_file_picker(function(filepath)
      -- Insert @file:path at cursor
      local cursor = vim.api.nvim_win_get_cursor(M.state.input_winnr)
      local line = vim.api.nvim_buf_get_lines(input_bufnr, cursor[1] - 1, cursor[1], false)[1]

      local before = line:sub(1, cursor[2])
      local after = line:sub(cursor[2] + 1)
      local new_line = before .. "@file:" .. filepath .. " " .. after

      vim.api.nvim_buf_set_lines(input_bufnr, cursor[1] - 1, cursor[1], false, { new_line })

      -- Move cursor after inserted text
      vim.api.nvim_win_set_cursor(M.state.input_winnr, { cursor[1], #before + #filepath + 7 })
    end)
  end, { buffer = input_bufnr, silent = true })
end

-- Open the agent interface
function M.open()
  logger.info("agent", "Opening ZekeCode interface")

  local chat_bufnr = get_or_create_chat_buffer()
  local input_bufnr = get_or_create_input_buffer()

  -- Get dimensions
  local width = vim.o.columns
  local height = vim.o.lines

  local chat_height = math.floor(height * 0.7)
  local input_height = math.floor(height * 0.2)

  -- Create chat window (top)
  M.state.chat_winnr = vim.api.nvim_open_win(chat_bufnr, false, {
    relative = 'editor',
    width = width,
    height = chat_height,
    row = 0,
    col = 0,
    style = 'minimal',
    border = 'rounded',
  })

  -- Set statusline
  vim.api.nvim_set_option_value('statusline', get_statusline(), { win = M.state.chat_winnr })

  -- Create input window (bottom)
  M.state.input_winnr = vim.api.nvim_open_win(input_bufnr, true, {
    relative = 'editor',
    width = width,
    height = input_height,
    row = chat_height + 2,
    col = 0,
    style = 'minimal',
    border = 'rounded',
    title = ' Type message (CR to send, Tab to cycle models) ',
    title_pos = 'center',
  })

  -- Setup keymaps
  setup_agent_keymaps(chat_bufnr, input_bufnr)

  -- Welcome message if chat is empty
  if vim.api.nvim_buf_line_count(chat_bufnr) <= 1 then
    local welcome = string.format(
      "Welcome to ZekeCode!\n\nCurrent model: %s %s\n\nCommands:\n- Type your message and press <CR> to send\n- <Tab> to cycle models\n- <leader>m for model picker\n- <C-l> to clear chat\n- <Esc> to close",
      models.get_current().icon,
      models.get_current().name
    )
    append_to_chat(welcome, "assistant")
  end

  -- Start in insert mode
  vim.cmd('startinsert')
end

-- Close the agent interface
function M.close()
  if M.state.chat_winnr and vim.api.nvim_win_is_valid(M.state.chat_winnr) then
    vim.api.nvim_win_close(M.state.chat_winnr, true)
  end

  if M.state.input_winnr and vim.api.nvim_win_is_valid(M.state.input_winnr) then
    vim.api.nvim_win_close(M.state.input_winnr, true)
  end

  M.state.chat_winnr = nil
  M.state.input_winnr = nil
end

-- Toggle agent interface
function M.toggle()
  if M.state.chat_winnr and vim.api.nvim_win_is_valid(M.state.chat_winnr) then
    M.close()
  else
    M.open()
  end
end

-- Send message from input buffer
function M.send_message()
  local input_bufnr = M.state.input_bufnr
  if not input_bufnr or not vim.api.nvim_buf_is_valid(input_bufnr) then
    return
  end

  -- Get message from input buffer
  local lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  local message = table.concat(lines, "\n"):gsub("^%s*(.-)%s*$", "%1")  -- Trim

  if message == "" then
    return
  end

  logger.info("agent", "Sending message: " .. message)

  -- Parse @-mentions
  local parsed_mentions = mentions.parse(message)

  -- Show context chips if mentions found
  if #parsed_mentions > 0 then
    local chips = mentions.get_chips(parsed_mentions)
    logger.info("agent", string.format("Found %d mentions", #parsed_mentions))

    -- Show chips inline in chat
    local chat_bufnr = M.state.chat_bufnr
    if chat_bufnr and vim.api.nvim_buf_is_valid(chat_bufnr) then
      local line_count = vim.api.nvim_buf_line_count(chat_bufnr)
      context_chips.show_inline(chat_bufnr, line_count - 1, chips)
    end
  end

  -- Process message with context
  local processed_message, _ = mentions.process(message)

  -- Check safety before sending
  local is_safe, safety_check = safety.check_safety({
    prompt = processed_message,
    operation_type = "chat",
  })

  -- Show safety confirmation if needed
  if not is_safe or (safety_check and #safety_check.warnings > 0) then
    safety.show_safety_dialog(safety_check, function(confirmed)
      if not confirmed then
        logger.info("agent", "Message cancelled by user")
        return
      end
      -- Continue with sending
      M._do_send_message(input_bufnr, message, processed_message)
    end)
  else
    -- Safe to proceed directly
    M._do_send_message(input_bufnr, message, processed_message)
  end
end

-- Internal helper to actually send the message
function M._do_send_message(input_bufnr, message, processed_message)
  local current_model = models.get_current()

  -- Show token estimate
  tokens.show_estimate_prompt(processed_message, current_model.name, function(confirmed, estimate)
    if not confirmed then
      logger.info("agent", "Message cancelled by user")
      return
    end

    -- Track token usage
    if estimate then
      tokens.track_usage(estimate.input_tokens, estimate.output_tokens, estimate.cost)
    end

    -- Track rate limiting
    safety.track_request()

    -- Clear input buffer
    vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, false, {})

    -- Add user message to chat (original message without expanded context)
    append_to_chat(message, "user")

    -- Add to history (processed message with context for AI)
    table.insert(M.state.conversation_history, { role = "user", content = processed_message })

    -- Show "thinking" indicator
    append_to_chat("...", "assistant")

    -- Start progress indicator
    local progress_id = progress.loading("Waiting for AI response")

    -- Send to CLI (streaming) with processed message
    M.state.current_job = cli.stream_chat(
      processed_message,
    function(chunk)
      -- Update last message with streamed content
      local chat_bufnr = M.state.chat_bufnr
      if not chat_bufnr or not vim.api.nvim_buf_is_valid(chat_bufnr) then
        return
      end

      -- Replace "..." with actual content
      local line_count = vim.api.nvim_buf_line_count(chat_bufnr)
      local last_line = vim.api.nvim_buf_get_lines(chat_bufnr, line_count - 1, line_count, false)[1]

      if last_line == "..." then
        vim.api.nvim_buf_set_lines(chat_bufnr, line_count - 1, line_count, false, { chunk })
      else
        vim.api.nvim_buf_set_lines(chat_bufnr, line_count, line_count, false, { chunk })
      end

      -- Auto-scroll
      if M.state.chat_winnr and vim.api.nvim_win_is_valid(M.state.chat_winnr) then
        vim.api.nvim_win_set_cursor(M.state.chat_winnr, { vim.api.nvim_buf_line_count(chat_bufnr), 0 })
      end
    end,
      function(full_response, exit_code)
        -- Stop progress
        progress.stop(progress_id)

        if exit_code == 0 then
          logger.info("agent", "Response received")
          table.insert(M.state.conversation_history, { role = "assistant", content = full_response })

          -- Update token usage with actual output
          if estimate then
            local output_tokens = tokens.estimate_tokens(full_response)
            local actual_cost = tokens.calculate_cost(estimate.input_tokens, output_tokens, current_model.name)
            tokens.track_usage(estimate.input_tokens, output_tokens, actual_cost)
          end
        else
          append_to_chat("Error: Request failed", "assistant")
          logger.error("agent", "Request failed with exit code " .. exit_code)
        end
        M.state.current_job = nil
      end
    )
  end)
end

-- Clear chat history
function M.clear_chat()
  local bufnr = M.state.chat_bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  M.state.conversation_history = {}

  vim.notify("Chat cleared", vim.log.levels.INFO)
end

-- Save conversation to file
function M.save_conversation(filepath)
  filepath = filepath or vim.fn.stdpath('data') .. '/zeke_conversation_' .. os.date('%Y%m%d_%H%M%S') .. '.md'

  local lines = vim.api.nvim_buf_get_lines(M.state.chat_bufnr, 0, -1, false)
  local file = io.open(filepath, 'w')

  if not file then
    vim.notify("Failed to save conversation", vim.log.levels.ERROR)
    return
  end

  file:write(table.concat(lines, '\n'))
  file:close()

  vim.notify("Conversation saved to: " .. filepath, vim.log.levels.INFO)
end

return M
