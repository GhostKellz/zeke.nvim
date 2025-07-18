# zeke.nvim Plugin Integration

This document outlines how to create a Neovim plugin that integrates with the zeke CLI tool.

zeke - github.com/ghostkellz/zeke
## Plugin Structure

```
zeke.nvim/
├── lua/
│   └── zeke/
│       ├── init.lua
│       ├── terminal.lua
│       ├── commands.lua
│       └── config.lua
└── plugin/
    └── zeke.vim
```

## Core Implementation

### 1. Terminal Wrapper (`lua/zeke/terminal.lua`)

```lua
local M = {}

local config = require('zeke.config')

-- Create floating terminal window
function M.create_float()
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = 'Zeke AI',
    title_pos = 'center'
  })
  
  return buf, win
end

-- Run zeke command in terminal
function M.run_command(cmd, opts)
  opts = opts or {}
  
  local buf, win = M.create_float()
  
  local full_cmd = config.get().cmd .. ' ' .. cmd
  
  vim.fn.termopen(full_cmd, {
    on_exit = function(_, code)
      if opts.on_exit then
        opts.on_exit(code)
      end
    end
  })
  
  vim.cmd('startinsert')
  
  -- Set up keymaps for terminal
  vim.api.nvim_buf_set_keymap(buf, 't', '<Esc>', '<C-\\><C-n>', {noremap = true})
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', {noremap = true})
  
  return buf, win
end

return M
```

### 2. Commands (`lua/zeke/commands.lua`)

```lua
local M = {}

local terminal = require('zeke.terminal')

-- Chat command
function M.chat(message)
  local cmd = string.format('nvim chat "%s"', message or '')
  terminal.run_command(cmd)
end

-- Edit current buffer
function M.edit_buffer(instruction)
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code = table.concat(lines, '\n')
  
  -- Escape quotes in code
  code = code:gsub('"', '\\"')
  instruction = instruction or ''
  
  local cmd = string.format('nvim edit "%s" "%s"', code, instruction)
  terminal.run_command(cmd, {
    on_exit = function(code)
      if code == 0 then
        -- Reload buffer after successful edit
        vim.cmd('checktime')
      end
    end
  })
end

-- Explain current selection or buffer
function M.explain(code)
  if not code then
    -- Get visual selection or current buffer
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    code = table.concat(lines, '\n')
  end
  
  code = code:gsub('"', '\\"')
  local cmd = string.format('nvim explain "%s"', code)
  terminal.run_command(cmd)
end

-- Create new file
function M.create_file(description)
  local cmd = string.format('nvim create "%s"', description or '')
  terminal.run_command(cmd)
end

-- Analyze code
function M.analyze(analysis_type, code)
  if not code then
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    code = table.concat(lines, '\n')
  end
  
  code = code:gsub('"', '\\"')
  analysis_type = analysis_type or 'quality'
  
  local cmd = string.format('nvim analyze "%s" %s', code, analysis_type)
  terminal.run_command(cmd)
end

return M
```

### 3. Configuration (`lua/zeke/config.lua`)

```lua
local M = {}

local defaults = {
  cmd = 'zeke',
  auto_reload = true,
  keymaps = {
    chat = '<leader>zc',
    edit = '<leader>ze',
    explain = '<leader>zx',
    create = '<leader>zf',
    analyze = '<leader>za'
  }
}

local config = defaults

function M.setup(opts)
  config = vim.tbl_deep_extend('force', defaults, opts or {})
end

function M.get()
  return config
end

return M
```

### 4. Main Plugin (`lua/zeke/init.lua`)

```lua
local M = {}

local config = require('zeke.config')
local commands = require('zeke.commands')

function M.setup(opts)
  config.setup(opts)
  
  -- Set up user commands
  vim.api.nvim_create_user_command('ZekeChat', function(args)
    commands.chat(args.args)
  end, { nargs = '?', desc = 'Chat with Zeke AI' })
  
  vim.api.nvim_create_user_command('ZekeEdit', function(args)
    commands.edit_buffer(args.args)
  end, { nargs = '?', desc = 'Edit current buffer with Zeke' })
  
  vim.api.nvim_create_user_command('ZekeExplain', function()
    commands.explain()
  end, { desc = 'Explain current buffer with Zeke' })
  
  vim.api.nvim_create_user_command('ZekeCreate', function(args)
    commands.create_file(args.args)
  end, { nargs = '?', desc = 'Create file with Zeke' })
  
  vim.api.nvim_create_user_command('ZekeAnalyze', function(args)
    local analysis_type = args.args or 'quality'
    commands.analyze(analysis_type)
  end, { nargs = '?', desc = 'Analyze code with Zeke' })
  
  -- Set up keymaps
  local keymaps = config.get().keymaps
  if keymaps.chat then
    vim.keymap.set('n', keymaps.chat, function()
      vim.ui.input({prompt = 'Chat: '}, function(input)
        if input then commands.chat(input) end
      end)
    end, { desc = 'Chat with Zeke' })
  end
  
  if keymaps.edit then
    vim.keymap.set('n', keymaps.edit, function()
      vim.ui.input({prompt = 'Edit instruction: '}, function(input)
        if input then commands.edit_buffer(input) end
      end)
    end, { desc = 'Edit buffer with Zeke' })
  end
  
  if keymaps.explain then
    vim.keymap.set('n', keymaps.explain, commands.explain, { desc = 'Explain with Zeke' })
  end
  
  if keymaps.create then
    vim.keymap.set('n', keymaps.create, function()
      vim.ui.input({prompt = 'Create file: '}, function(input)
        if input then commands.create_file(input) end
      end)
    end, { desc = 'Create file with Zeke' })
  end
  
  if keymaps.analyze then
    vim.keymap.set('n', keymaps.analyze, function()
      commands.analyze('quality')
    end, { desc = 'Analyze code with Zeke' })
  end
  
  -- Auto-reload files if enabled
  if config.get().auto_reload then
    vim.api.nvim_create_autocmd('FocusGained', {
      pattern = '*',
      command = 'checktime'
    })
  end
end

-- Expose command functions
M.chat = commands.chat
M.edit = commands.edit_buffer
M.explain = commands.explain
M.create = commands.create_file
M.analyze = commands.analyze

return M
```

## Usage

### Installation (lazy.nvim)

```lua
{
  'your-username/zeke.nvim',
  config = function()
    require('zeke').setup({
      cmd = 'zeke',  -- Path to zeke binary
      auto_reload = true,
      keymaps = {
        chat = '<leader>zc',
        edit = '<leader>ze',
        explain = '<leader>zx',
        create = '<leader>zf',
        analyze = '<leader>za'
      }
    })
  end
}
```

### Commands

- `:ZekeChat [message]` - Chat with Zeke AI
- `:ZekeEdit [instruction]` - Edit current buffer
- `:ZekeExplain` - Explain current buffer
- `:ZekeCreate [description]` - Create new file
- `:ZekeAnalyze [type]` - Analyze code (quality/security/performance)

### Keymaps (default)

- `<leader>zc` - Chat with Zeke
- `<leader>ze` - Edit current buffer
- `<leader>zx` - Explain current buffer  
- `<leader>zf` - Create new file
- `<leader>za` - Analyze code

## Integration Points

The plugin expects these zeke CLI commands to work:

```bash
zeke nvim chat "message"
zeke nvim edit "code" "instruction"  
zeke nvim explain "code"
zeke nvim create "description"
zeke nvim analyze "code" "type"
```

Your existing CLI implementation already supports these commands in `src/main.zig`.
