-- Enhanced chat UI with history and persistence
local M = {}

local http = require('zeke.http_client')
local resources = require('zeke.resources')
local logger = require('zeke.logger')

local state = {
  buf = nil,
  win = nil,
  history = {},
  input_buf = nil,
  input_win = nil,
  is_open = false,
  active_request_id = nil, -- Track active API request
}

-- Open the chat UI
function M.open()
  if state.is_open then
    M.focus()
    return
  end

  -- Load history from disk
  M.load_history()

  -- Create chat buffer if doesn't exist
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.buf, 'filetype', 'markdown')
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
    vim.api.nvim_buf_set_name(state.buf, 'Zeke Chat')
  end

  -- Calculate size
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Open main chat window
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = 'editor',
    width = width,
    height = height - 4, -- Leave room for input
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Zeke Chat ',
    title_pos = 'center',
  })

  -- Create input window at bottom
  state.input_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.input_buf, 'buftype', 'prompt')
  vim.fn.prompt_setprompt(state.input_buf, '> ')

  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative = 'editor',
    width = width,
    height = 3,
    row = row + height - 3,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Message (Ctrl+S to send, q to close) ',
    title_pos = 'center',
  })

  -- Set up keymaps
  M.setup_keymaps()

  -- Render history
  M.render_history()

  state.is_open = true

  -- Focus input
  vim.api.nvim_set_current_win(state.input_win)
  vim.cmd('startinsert')

  logger.info('ui.chat', 'Chat UI opened')
end

-- Focus the chat window
function M.focus()
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_set_current_win(state.input_win)
    vim.cmd('startinsert')
  end
end

-- Setup keymaps
function M.setup_keymaps()
  -- In input window
  local input_opts = { buffer = state.input_buf, noremap = true, silent = true }

  -- Send message on Ctrl+S
  vim.keymap.set('i', '<C-s>', function()
    M.send_message()
  end, input_opts)

  -- Also allow Enter to send
  vim.keymap.set('i', '<CR>', function()
    M.send_message()
  end, input_opts)

  -- Close on Escape (or cancel active request)
  vim.keymap.set('i', '<Esc>', function()
    if state.active_request_id then
      -- Cancel active request
      if http.cancel_request(state.active_request_id) then
        vim.notify('Request cancelled', vim.log.levels.INFO)
        -- Remove thinking indicator
        if #state.history > 0 and state.history[#state.history].content:match('🤔 Thinking') then
          table.remove(state.history)
        end
        M.add_assistant_message("❌ **Cancelled** by user")
        M.render_history()
        M.save_history()
        state.active_request_id = nil
      end
    else
      M.close()
    end
  end, input_opts)

  -- In chat window
  local chat_opts = { buffer = state.buf, noremap = true, silent = true }

  -- Close on q
  vim.keymap.set('n', 'q', function()
    M.close()
  end, chat_opts)

  -- Clear history on C
  vim.keymap.set('n', 'C', function()
    M.clear_history()
  end, chat_opts)

  -- Copy last response on y
  vim.keymap.set('n', 'y', function()
    M.copy_last_response()
  end, chat_opts)

  -- Back to input on i
  vim.keymap.set('n', 'i', function()
    M.focus()
  end, chat_opts)
end

-- Send message
function M.send_message()
  local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)

  -- Remove prompt character
  local message = table.concat(lines, '\n')
  message = message:gsub('^> ', '')
  message = vim.trim(message)

  if message == '' then
    return
  end

  logger.info('ui.chat', 'Sending message: ' .. message:sub(1, 50))

  -- Add to history
  table.insert(state.history, {
    role = 'user',
    content = message,
    timestamp = os.time(),
  })

  -- Clear input
  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, {})

  -- Render immediately
  M.render_history()

  -- Send to API (async)
  M.send_to_api(message)
end

-- Send to API
function M.send_to_api(message)
  -- Add thinking indicator
  M.add_assistant_message("_🤔 Thinking... (Press ESC to cancel)_")

  -- Parse resources and send
  vim.schedule(function()
    local enhanced_message = resources.process_message(message)

    local ok, res = pcall(http.chat, enhanced_message, {
      language = vim.bo.filetype,
      intent = 'chat',
    })

    -- Store request ID if available
    if ok and res and res._request_id then
      state.active_request_id = res._request_id
    end

    -- Remove thinking indicator
    if #state.history > 0 and state.history[#state.history].content:match('🤔 Thinking') then
      table.remove(state.history)
    end

    -- Clear active request
    state.active_request_id = nil

    if ok then
      -- Check if cancelled
      if type(res) == 'table' and res.cancelled then
        -- Already handled by ESC handler
        return
      end

      -- Add response
      table.insert(state.history, {
        role = 'assistant',
        content = res.response,
        model = res.model,
        provider = res.provider,
        latency_ms = res.latency_ms,
        timestamp = os.time(),
      })

      logger.info('ui.chat', string.format('Response received: %s via %s (%dms)',
        res.model or 'unknown', res.provider or 'unknown', res.latency_ms or 0))
    else
      -- Check if cancelled
      if type(res) == 'table' and res.cancelled then
        -- Already handled by ESC handler
        return
      end

      -- Show error
      M.add_assistant_message("❌ **Error**: " .. tostring(res))
      logger.error('ui.chat', 'Chat failed: ' .. tostring(res))
    end

    M.render_history()
    M.save_history()
  end)
end

-- Add assistant message
function M.add_assistant_message(content)
  table.insert(state.history, {
    role = 'assistant',
    content = content,
    timestamp = os.time(),
  })
  M.render_history()
end

-- Render history
function M.render_history()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local lines = {}

  if #state.history == 0 then
    -- Show welcome message
    lines = {
      "# 💬 Zeke Chat",
      "",
      "Welcome! Start chatting with AI. Your conversation is automatically saved.",
      "",
      "## 🏷️ Resource Tags",
      "",
      "You can reference context in your messages:",
      "- `#buffer` - Include current buffer",
      "- `#selection` - Include current selection",
      "- `#file:/path/to/file` - Include a specific file",
      "- `#diagnostics` - Include LSP diagnostics",
      "- `#gitdiff` - Include staged git changes",
      "- `#git` - Include unstaged changes",
      "- `#open` - List all open files",
      "",
      "## 📝 Examples",
      "",
      "```",
      "> #buffer explain this code",
      "> #selection optimize this function",
      "> #file:src/main.lua #diagnostics fix the errors",
      "> #gitdiff review these changes",
      "```",
      "",
      "## ⌨️ Keybindings",
      "",
      "- `<CR>` or `<C-s>` - Send message",
      "- `<Esc>` - Cancel active request or close chat",
      "- `q` - Close chat (normal mode)",
      "- `C` - Clear history",
      "- `y` - Copy last AI response",
      "- `i` - Return to input",
      "",
      "---",
      "",
    }
  else
    -- Render conversation
    for i, entry in ipairs(state.history) do
      local time_str = os.date("%H:%M:%S", entry.timestamp)

      if entry.role == 'user' then
        table.insert(lines, string.format("## 👤 You · %s", time_str))
        table.insert(lines, "")
        for line in entry.content:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
      else
        local model_info = ""
        if entry.model then
          model_info = string.format(" · %s via %s", entry.model, entry.provider or "unknown")
          if entry.latency_ms then
            model_info = model_info .. string.format(" · %dms", entry.latency_ms)
          end
        end
        table.insert(lines, string.format("## 🤖 Zeke%s · %s", model_info, time_str))
        table.insert(lines, "")
        for line in entry.content:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
      end

      table.insert(lines, "")
      if i < #state.history then
        table.insert(lines, "---")
        table.insert(lines, "")
      end
    end
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)

  -- Scroll to bottom
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_cursor(state.win, {#lines, 0})
  end
end

-- Clear history
function M.clear_history()
  vim.ui.select({'Yes', 'No'}, {
    prompt = 'Clear chat history?',
  }, function(choice)
    if choice == 'Yes' then
      state.history = {}
      M.render_history()
      M.save_history()
      vim.notify('Chat history cleared', vim.log.levels.INFO)
    end
  end)
end

-- Copy last response
function M.copy_last_response()
  for i = #state.history, 1, -1 do
    if state.history[i].role == 'assistant' then
      vim.fn.setreg('+', state.history[i].content)
      vim.notify('Last AI response copied to clipboard', vim.log.levels.INFO)
      return
    end
  end
  vim.notify('No AI response to copy', vim.log.levels.WARN)
end

-- Close chat
function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_win_close(state.input_win, true)
  end

  state.is_open = false

  -- Save history
  M.save_history()

  logger.info('ui.chat', 'Chat UI closed')
end

-- Toggle chat (open if closed, close if open)
function M.toggle()
  if state.is_open then
    M.close()
  else
    M.open()
  end
end

-- Save history to disk
function M.save_history()
  local file = vim.fn.stdpath('data') .. '/zeke_chat_history.json'
  local content = vim.json.encode(state.history)
  local ok, err = pcall(vim.fn.writefile, {content}, file)
  if not ok then
    logger.error('ui.chat', 'Failed to save history: ' .. tostring(err))
  else
    logger.debug('ui.chat', 'History saved')
  end
end

-- Load history from disk
function M.load_history()
  local file = vim.fn.stdpath('data') .. '/zeke_chat_history.json'
  if vim.fn.filereadable(file) == 1 then
    local ok, content = pcall(vim.fn.readfile, file)
    if ok and content and #content > 0 then
      local decode_ok, history = pcall(vim.json.decode, content[1])
      if decode_ok and history then
        state.history = history
        logger.debug('ui.chat', string.format('Loaded %d messages from history', #state.history))
      end
    end
  end
end

return M
