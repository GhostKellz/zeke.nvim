# Statusline Integration

zeke.nvim provides statusline components to show AI model status, token usage, and request progress directly in your Neovim statusline.

## Features

- **Model Display**: Shows current AI model with icon
- **Token Usage**: Displays token count and estimated costs
- **Request Progress**: Shows active request status
- **Rate Limiting**: Warns when approaching rate limits
- **Lualine Support**: Ready-made components for lualine.nvim

## Installation

### Standalone Statusline

If you're not using a statusline plugin:

```lua
require('zeke').setup({
  statusline = {
    enabled = true,
  }
})

-- Add to your statusline
vim.o.statusline = '%<%f %h%m%r%=%{v:lua.require("zeke.statusline").get_statusline()} %-14.(%l,%c%V%) %P'
```

### With Lualine

For lualine.nvim users, add the zeke component:

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      -- Add all-in-one component
      require('zeke.statusline').lualine_status,

      -- Or add individual components
      -- require('zeke.statusline').lualine_model,
      -- require('zeke.statusline').lualine_tokens,
      -- require('zeke.statusline').lualine_requests,
      -- require('zeke.statusline').lualine_rate_limit,

      'encoding',
      'fileformat',
      'filetype',
    },
  },
})
```

### Automatic Integration

Let zeke.nvim automatically configure lualine:

```lua
local statusline = require('zeke.statusline')
local lualine_config = statusline.setup_lualine({
  -- Your existing lualine config
})

require('lualine').setup(lualine_config)
```

## Configuration

Configure statusline options:

```lua
require('zeke').setup({
  statusline = {
    enabled = true,
    show_model = true,
    show_tokens = true,
    show_requests = true,
    show_rate_limit = true,

    icons = {
      model = '🤖',
      tokens = '💰',
      request = '⚡',
      rate_limit_ok = '🟢',
      rate_limit_warn = '🟡',
      rate_limit_critical = '🔴',
    },
  },
})
```

## Components

### Full Status

Shows all components in one line:

```lua
require('zeke.statusline').get_statusline()
-- Example: "🤖 claude-sonnet-4 │ 💰 $0.12 │ ⚡ in_progress │ 🟢 5/min"
```

### Individual Components

#### Model
```lua
require('zeke.statusline').get_model()
-- Example: "🤖 claude-sonnet-4"
```

#### Token Usage
```lua
require('zeke.statusline').get_tokens()
-- Example: "💰 $0.12" or "💰 15k" (for free models)
```

#### Active Requests
```lua
require('zeke.statusline').get_requests()
-- Example: "⚡ in_progress" or "⚡ in_progress (+2)"
```

#### Rate Limiting
```lua
require('zeke.statusline').get_rate_limit()
-- Example: "🟢 5/min" or "🟡 12/min" or "🔴 21/min"
```

## Statusline Display Examples

### Normal Usage
```
🤖 qwen2.5-coder:7b
```
Shows model when idle.

### Active Request
```
🤖 claude-sonnet-4 │ ⚡ in_progress
```
Shows request in progress.

### With Token Usage
```
🤖 gpt-4o │ 💰 $0.45 │ 🟢 3/min
```
Shows model, cost, and rate limit.

### High Rate Limit Warning
```
🤖 claude-sonnet-4 │ 💰 $1.23 │ 🟡 15/min
```
Yellow indicator warns of high request rate.

### Multiple Requests
```
🤖 gemini-pro │ ⚡ in_progress (+2) │ 🔴 22/min
```
Shows 3 active requests and critical rate limit.

## Lualine Component Reference

### Individual Components

```lua
-- Model info
{
  require('zeke.statusline').lualine_model,
  cond = function() return true end,
}

-- Token usage (only shows when non-zero)
{
  require('zeke.statusline').lualine_tokens,
  cond = function() return true end,
}

-- Active requests (only shows when active)
{
  require('zeke.statusline').lualine_requests,
  cond = function() return true end,
}

-- Rate limiting status
{
  require('zeke.statusline').lualine_rate_limit,
  cond = function() return true end,
}

-- All-in-one component
{
  require('zeke.statusline').lualine_status,
  cond = function() return true end,
}
```

### Color Configuration

Customize lualine colors for zeke components:

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      {
        require('zeke.statusline').lualine_status,
        color = { fg = '#7aa2f7', bg = '#1f2335' },
      },
    },
  },
})
```

## Auto-Updates

Statusline automatically updates on:
- Request start/completion
- Model changes
- Token usage updates
- Rate limiting changes (every 5 seconds)

### Manual Updates

Force a statusline update:

```lua
require('zeke.statusline').update()
```

## Events

Zeke fires custom events for statusline updates:

```lua
-- ZekeRequestStart - Fired when request begins
-- ZekeRequestComplete - Fired when request completes
-- ZekeModelChanged - Fired when model changes

-- Listen to events
vim.api.nvim_create_autocmd('User', {
  pattern = 'ZekeRequestStart',
  callback = function()
    print('Request started!')
  end,
})
```

## Troubleshooting

### Statusline Not Showing

Check if statusline is enabled:
```vim
:echo &statusline
:echo &laststatus
```

Ensure laststatus is 2 or 3:
```lua
vim.o.laststatus = 2  -- Always show statusline
```

### Components Not Updating

Setup autocommands:
```lua
require('zeke.statusline').setup_autocommands()
```

### Icons Not Displaying

Use ASCII icons instead:
```lua
require('zeke').setup({
  statusline = {
    icons = {
      model = '[M]',
      tokens = '$',
      request = '*',
      rate_limit_ok = 'OK',
      rate_limit_warn = 'WARN',
      rate_limit_critical = 'CRIT',
    },
  },
})
```

## Tips

1. **Hide When Idle**: Components auto-hide when not relevant (e.g., no active requests)
2. **Cost Tracking**: Token costs are estimates based on model pricing
3. **Free Models**: Shows token count instead of cost for Ollama models
4. **Rate Limits**: Helps avoid hitting API rate limits
5. **Multiple Requests**: Shows count of queued requests

## Integration Examples

### Minimal Setup
```lua
vim.o.statusline = '%f %=%{v:lua.require("zeke.statusline").get_model()}'
```

### With File Info
```lua
vim.o.statusline = '%<%f %h%m%r%=%{v:lua.require("zeke.statusline").get_statusline()} %-14.(%l,%c%V%)'
```

### Full Featured
```lua
require('lualine').setup({
  options = {
    theme = 'auto',
    component_separators = '|',
    section_separators = '',
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {
      require('zeke.statusline').lualine_status,
      'encoding',
      'fileformat',
      'filetype'
    },
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
})
```
