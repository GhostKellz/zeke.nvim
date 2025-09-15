local M = {}

-- State management for floating windows
M.chat_buf = nil
M.chat_win = nil
M.input_buf = nil
M.input_win = nil
M.is_chat_open = false

-- Chat history
M.chat_history = {}
M.current_conversation = {}

function M.setup()
  -- Create autocommands for cleanup
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      M.close_chat()
    end,
  })
end

function M.create_floating_window(config)
  local default_config = {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    focusable = true,
  }

  config = vim.tbl_deep_extend('force', default_config, config or {})

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, config)

  return buf, win
end

function M.calculate_chat_dimensions()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local chat_height = math.floor(height * 0.85)
  local input_height = height - chat_height - 1

  return {
    chat = {
      width = width,
      height = chat_height,
      row = row,
      col = col,
    },
    input = {
      width = width,
      height = input_height,
      row = row + chat_height + 1,
      col = col,
    }
  }
end

function M.open_chat()
  if M.is_chat_open then
    M.focus_chat()
    return
  end

  local dims = M.calculate_chat_dimensions()

  -- Create chat display window
  M.chat_buf, M.chat_win = M.create_floating_window({
    width = dims.chat.width,
    height = dims.chat.height,
    row = dims.chat.row,
    col = dims.chat.col,
    title = ' Zeke Chat ',
    title_pos = 'center',
  })

  -- Create input window
  M.input_buf, M.input_win = M.create_floating_window({
    width = dims.input.width,
    height = dims.input.height,
    row = dims.input.row,
    col = dims.input.col,
    title = ' Input (Ctrl+S to send, Esc to close) ',
    title_pos = 'center',
  })

  -- Configure chat buffer
  vim.api.nvim_buf_set_option(M.chat_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.chat_buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(M.chat_buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(M.chat_buf, 'modifiable', false)

  -- Configure input buffer
  vim.api.nvim_buf_set_option(M.input_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.input_buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(M.input_buf, 'filetype', 'markdown')

  -- Set up keymaps for input window
  local input_opts = { buffer = M.input_buf, noremap = true, silent = true }
  vim.keymap.set('n', '<Esc>', M.close_chat, input_opts)
  vim.keymap.set('i', '<Esc>', M.close_chat, input_opts)
  vim.keymap.set('n', '<C-s>', M.send_message, input_opts)
  vim.keymap.set('i', '<C-s>', M.send_message, input_opts)
  vim.keymap.set('n', '<C-c>', M.clear_chat, input_opts)
  vim.keymap.set('i', '<C-c>', M.clear_chat, input_opts)

  -- Set up keymaps for chat window
  local chat_opts = { buffer = M.chat_buf, noremap = true, silent = true }
  vim.keymap.set('n', '<Esc>', M.close_chat, chat_opts)
  vim.keymap.set('n', 'q', M.close_chat, chat_opts)
  vim.keymap.set('n', '<C-c>', M.clear_chat, chat_opts)

  -- Focus input window and enter insert mode
  vim.api.nvim_set_current_win(M.input_win)
  vim.cmd('startinsert')

  M.is_chat_open = true

  -- Display welcome message
  M.add_system_message("Zeke Chat initialized. Type your message and press Ctrl+S to send.")
  M.display_conversation()
end

function M.close_chat()
  if M.chat_win and vim.api.nvim_win_is_valid(M.chat_win) then
    vim.api.nvim_win_close(M.chat_win, true)
  end

  if M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    vim.api.nvim_win_close(M.input_win, true)
  end

  if M.chat_buf and vim.api.nvim_buf_is_valid(M.chat_buf) then
    vim.api.nvim_buf_delete(M.chat_buf, { force = true })
  end

  if M.input_buf and vim.api.nvim_buf_is_valid(M.input_buf) then
    vim.api.nvim_buf_delete(M.input_buf, { force = true })
  end

  M.chat_buf = nil
  M.chat_win = nil
  M.input_buf = nil
  M.input_win = nil
  M.is_chat_open = false
end

function M.focus_chat()
  if M.is_chat_open and M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    vim.api.nvim_set_current_win(M.input_win)
    vim.cmd('startinsert')
  end
end

function M.toggle_chat()
  if M.is_chat_open then
    M.close_chat()
  else
    M.open_chat()
  end
end

function M.add_message(role, content)
  table.insert(M.current_conversation, {
    role = role,
    content = content,
    timestamp = os.time(),
  })
end

function M.add_system_message(content)
  M.add_message('system', content)
end

function M.add_user_message(content)
  M.add_message('user', content)
end

function M.add_assistant_message(content)
  M.add_message('assistant', content)
end

function M.clear_chat()
  M.current_conversation = {}
  M.display_conversation()
  vim.notify('Chat cleared', vim.log.levels.INFO)
end

function M.send_message()
  if not M.input_buf or not vim.api.nvim_buf_is_valid(M.input_buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(M.input_buf, 0, -1, false)
  local message = table.concat(lines, '\n'):gsub('^%s*(.-)%s*$', '%1')

  if message == '' then
    vim.notify('Please enter a message', vim.log.levels.WARN)
    return
  end

  -- Add user message to conversation
  M.add_user_message(message)
  M.display_conversation()

  -- Clear input buffer
  vim.api.nvim_buf_set_lines(M.input_buf, 0, -1, false, {})

  -- Show processing message
  M.add_system_message('Processing...')
  M.display_conversation()

  -- Send to AI (asynchronously)
  vim.schedule(function()
    local zeke_nvim = require('zeke_nvim')
    local ok, response = pcall(zeke_nvim.chat, message)

    -- Remove processing message
    if M.current_conversation[#M.current_conversation].role == 'system' then
      table.remove(M.current_conversation)
    end

    if ok then
      M.add_assistant_message(response)
    else
      M.add_system_message('Error: ' .. tostring(response))
    end

    M.display_conversation()
  end)
end

function M.display_conversation()
  if not M.chat_buf or not vim.api.nvim_buf_is_valid(M.chat_buf) then
    return
  end

  local lines = {}

  for _, msg in ipairs(M.current_conversation) do
    local timestamp = os.date('%H:%M:%S', msg.timestamp)
    local role_color = ''
    local role_prefix = ''

    if msg.role == 'user' then
      role_prefix = '󰭹 You'
      role_color = '# '
    elseif msg.role == 'assistant' then
      role_prefix = '🤖 Zeke'
      role_color = '## '
    elseif msg.role == 'system' then
      role_prefix = '⚙️ System'
      role_color = '### '
    end

    table.insert(lines, '')
    table.insert(lines, role_color .. role_prefix .. ' (' .. timestamp .. ')')
    table.insert(lines, '')

    -- Split content into lines and add to display
    for _, line in ipairs(vim.split(msg.content, '\n')) do
      table.insert(lines, line)
    end

    table.insert(lines, '')
    table.insert(lines, '---')
  end

  -- Update buffer content
  vim.api.nvim_buf_set_option(M.chat_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(M.chat_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.chat_buf, 'modifiable', false)

  -- Scroll to bottom
  if M.chat_win and vim.api.nvim_win_is_valid(M.chat_win) then
    local line_count = vim.api.nvim_buf_line_count(M.chat_buf)
    vim.api.nvim_win_set_cursor(M.chat_win, {line_count, 0})
  end
end

function M.save_conversation()
  if #M.current_conversation == 0 then
    vim.notify('No conversation to save', vim.log.levels.WARN)
    return
  end

  table.insert(M.chat_history, {
    conversation = vim.deepcopy(M.current_conversation),
    timestamp = os.time(),
  })

  vim.notify('Conversation saved to history', vim.log.levels.INFO)
end

function M.load_conversation(index)
  if not M.chat_history[index] then
    vim.notify('Invalid conversation index', vim.log.levels.ERROR)
    return
  end

  M.current_conversation = vim.deepcopy(M.chat_history[index].conversation)
  M.display_conversation()
  vim.notify('Conversation loaded from history', vim.log.levels.INFO)
end

function M.list_conversations()
  if #M.chat_history == 0 then
    vim.notify('No saved conversations', vim.log.levels.INFO)
    return
  end

  local items = {}
  for i, conv in ipairs(M.chat_history) do
    local timestamp = os.date('%Y-%m-%d %H:%M:%S', conv.timestamp)
    local first_user_msg = ''

    for _, msg in ipairs(conv.conversation) do
      if msg.role == 'user' then
        first_user_msg = msg.content:sub(1, 50)
        if #msg.content > 50 then
          first_user_msg = first_user_msg .. '...'
        end
        break
      end
    end

    table.insert(items, string.format('%d. [%s] %s', i, timestamp, first_user_msg))
  end

  vim.ui.select(items, {
    prompt = 'Select conversation to load:',
  }, function(choice, idx)
    if idx then
      M.load_conversation(idx)
    end
  end)
end

return M