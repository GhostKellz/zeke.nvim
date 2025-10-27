-- Enhanced chat panel with streaming responses
-- Inspired by CopilotChat and Claude Code

local M = {}

local api = vim.api
local cli = require('zeke.cli')
local logger = require('zeke.logger')
local config = require('zeke.config')

-- State
M.state = {
  win = nil,
  buf = nil,
  input_buf = nil,
  input_win = nil,
  history = {},
  is_streaming = false,
  current_message = {},
  job_id = nil,  -- Track streaming job
}

-- Create chat panel
function M.open()
  if M.is_open() then
    M.focus()
    return
  end

  local cfg = config.options.chat or {}
  local width = cfg.width or 80
  local height = cfg.height or 30

  -- Calculate window dimensions
  local ui = api.nvim_list_uis()[1]
  local win_width = math.floor(ui.width * 0.8)
  local win_height = math.floor(ui.height * 0.8)

  if width < 1 then
    win_width = math.floor(ui.width * width)
  else
    win_width = math.min(width, ui.width - 4)
  end

  if height < 1 then
    win_height = math.floor(ui.height * height)
  else
    win_height = math.min(height, ui.height - 4)
  end

  -- Create chat buffer
  M.state.buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(M.state.buf, 'bufhidden', 'hide')
  api.nvim_buf_set_option(M.state.buf, 'swapfile', false)
  api.nvim_buf_set_option(M.state.buf, 'filetype', 'zeke-chat')
  api.nvim_buf_set_name(M.state.buf, 'Zeke Chat')

  -- Create input buffer (bottom of chat)
  M.state.input_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.input_buf, 'buftype', 'prompt')
  api.nvim_buf_set_option(M.state.input_buf, 'filetype', 'zeke-input')
  vim.fn.prompt_setprompt(M.state.input_buf, '> ')
  vim.fn.prompt_setcallback(M.state.input_buf, function(text)
    M.send_message(text)
  end)

  -- Window options
  local win_opts = {
    relative = 'editor',
    width = win_width,
    height = win_height - 3,
    col = math.floor((ui.width - win_width) / 2),
    row = math.floor((ui.height - win_height) / 2),
    style = 'minimal',
    border = cfg.border or 'rounded',
    title = ' Zeke Chat ',
    title_pos = 'center',
  }

  -- Create chat window
  M.state.win = api.nvim_open_win(M.state.buf, true, win_opts)
  api.nvim_win_set_option(M.state.win, 'wrap', true)
  api.nvim_win_set_option(M.state.win, 'linebreak', true)
  api.nvim_win_set_option(M.state.win, 'cursorline', false)

  -- Create input window
  local input_opts = vim.tbl_extend('force', win_opts, {
    height = 3,
    row = win_opts.row + win_opts.height,
    title = ' Message ',
  })
  M.state.input_win = api.nvim_open_win(M.state.input_buf, true, input_opts)

  -- Setup keymaps
  M.setup_keymaps()

  -- Start in insert mode
  vim.cmd('startinsert')

  -- Render existing history
  M.render()
end

-- Check if panel is open
function M.is_open()
  return M.state.win and api.nvim_win_is_valid(M.state.win)
end

-- Focus chat panel
function M.focus()
  if M.is_open() then
    api.nvim_set_current_win(M.state.input_win)
    vim.cmd('startinsert')
  end
end

-- Close chat panel
function M.close()
  -- Cancel any ongoing streaming
  if M.state.job_id then
    cli.cancel_stream(M.state.job_id)
    M.state.job_id = nil
  end

  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    api.nvim_win_close(M.state.win, true)
  end
  if M.state.input_win and api.nvim_win_is_valid(M.state.input_win) then
    api.nvim_win_close(M.state.input_win, true)
  end
  M.state.win = nil
  M.state.input_win = nil
end

-- Toggle chat panel
function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

-- Send message
function M.send_message(text)
  if not text or text == '' then
    return
  end

  -- Add user message to history
  table.insert(M.state.history, {
    role = 'user',
    content = text,
    timestamp = os.time(),
  })

  -- Clear input
  api.nvim_buf_set_lines(M.state.input_buf, 0, -1, false, {})

  -- Start streaming response
  M.state.is_streaming = true
  M.state.current_message = {
    role = 'assistant',
    content = '',
    timestamp = os.time(),
  }

  -- Render user message immediately
  M.render()

  -- Call zeke CLI with streaming
  M.stream_response(text)
end

-- Stream response from zeke CLI
function M.stream_response(prompt)
  -- Add context if enabled
  local context_prompt = prompt
  local current_buf = vim.fn.bufnr('#')  -- Get previous buffer (not chat buffer)
  if current_buf and api.nvim_buf_is_valid(current_buf) then
    local filetype = api.nvim_buf_get_option(current_buf, 'filetype')
    if filetype ~= 'zeke-chat' and filetype ~= 'zeke-input' then
      -- Add file context to prompt
      local filename = api.nvim_buf_get_name(current_buf)
      if filename ~= '' then
        context_prompt = string.format("Context: Working on %s\n\n%s", filename, prompt)
      end
    end
  end

  -- Stream response using CLI
  M.state.job_id = cli.stream_chat(context_prompt,
    -- on_chunk callback
    function(chunk)
      M.state.current_message.content = M.state.current_message.content .. chunk
      vim.schedule(function()
        M.render()
      end)
    end,
    -- on_complete callback
    function(full_response, exit_code)
      vim.schedule(function()
        M.state.is_streaming = false
        M.state.job_id = nil
        if exit_code == 0 then
          table.insert(M.state.history, M.state.current_message)
          M.state.current_message = {}
        else
          vim.notify('Error getting response from Zeke (exit code: ' .. exit_code .. ')', vim.log.levels.ERROR)
        end
        M.render()
      end)
    end
  )
end

-- Render chat history
function M.render()
  if not M.state.buf or not api.nvim_buf_is_valid(M.state.buf) then
    return
  end

  local lines = {}
  local highlights = {}

  -- Header
  table.insert(lines, '╔═══════════════════════════════════════════════════════════════════════════╗')
  table.insert(lines, '║                          ZEKE AI ASSISTANT                                ║')
  table.insert(lines, '╚═══════════════════════════════════════════════════════════════════════════╝')
  table.insert(lines, '')

  -- Render history
  for _, msg in ipairs(M.state.history) do
    if msg.role == 'user' then
      table.insert(lines, '┌─ YOU ─────────────────────────────────────────────────────────────────┐')
      for _, line in ipairs(vim.split(msg.content, '\n')) do
        table.insert(lines, '│ ' .. line)
      end
      table.insert(lines, '└───────────────────────────────────────────────────────────────────────┘')
    else
      table.insert(lines, '┌─ ZEKE ────────────────────────────────────────────────────────────────┐')
      for _, line in ipairs(vim.split(msg.content, '\n')) do
        table.insert(lines, '│ ' .. line)
      end
      table.insert(lines, '└───────────────────────────────────────────────────────────────────────┘')
    end
    table.insert(lines, '')
  end

  -- Render current streaming message
  if M.state.is_streaming and M.state.current_message.content ~= '' then
    table.insert(lines, '┌─ ZEKE (streaming...) ─────────────────────────────────────────────────┐')
    for _, line in ipairs(vim.split(M.state.current_message.content, '\n')) do
      table.insert(lines, '│ ' .. line)
    end
    table.insert(lines, '│ ▋')  -- Cursor indicator
    table.insert(lines, '└───────────────────────────────────────────────────────────────────────┘')
  end

  -- Set lines
  api.nvim_buf_set_option(M.state.buf, 'modifiable', true)
  api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  api.nvim_buf_set_option(M.state.buf, 'modifiable', false)

  -- Auto-scroll to bottom
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    api.nvim_win_set_cursor(M.state.win, { #lines, 0 })
  end
end

-- Setup keymaps
function M.setup_keymaps()
  local function map(mode, lhs, rhs, desc)
    api.nvim_buf_set_keymap(M.state.buf, mode, lhs, rhs, {
      noremap = true,
      silent = true,
      desc = desc,
    })
    if M.state.input_buf then
      api.nvim_buf_set_keymap(M.state.input_buf, mode, lhs, rhs, {
        noremap = true,
        silent = true,
        desc = desc,
      })
    end
  end

  -- Close
  map('n', 'q', '<cmd>lua require("zeke.chat.panel").close()<CR>', 'Close chat')
  map('n', '<Esc>', '<cmd>lua require("zeke.chat.panel").close()<CR>', 'Close chat')

  -- Clear
  map('n', 'C', '<cmd>lua require("zeke.chat.panel").clear()<CR>', 'Clear chat')

  -- Navigate
  map('n', '<C-j>', '<cmd>lua require("zeke.chat.panel").next_message()<CR>', 'Next message')
  map('n', '<C-k>', '<cmd>lua require("zeke.chat.panel").prev_message()<CR>', 'Previous message')
end

-- Clear chat history
function M.clear()
  M.state.history = {}
  M.state.current_message = {}
  M.render()
  vim.notify('Chat history cleared', vim.log.levels.INFO)
end

-- Navigate to next message
function M.next_message()
  -- Implementation for navigation
end

-- Navigate to previous message
function M.prev_message()
  -- Implementation for navigation
end

-- Add context from selection
function M.add_context(context_type, content)
  -- Add context to next message
  -- context_type can be: 'buffer', 'selection', 'diagnostic', 'file'
end

return M
