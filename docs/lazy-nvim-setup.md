# Lazy.nvim Setup and Optimizations

## Basic Setup

```lua
{
  'ghostkellz/zeke.nvim',
  cmd = {
    'ZekeChat',
    'ZekeEdit', 
    'ZekeExplain',
    'ZekeCreate',
    'ZekeAnalyze'
  },
  keys = {
    { '<leader>zc', desc = 'Zeke Chat' },
    { '<leader>ze', desc = 'Zeke Edit' },
    { '<leader>zx', desc = 'Zeke Explain' },
    { '<leader>zf', desc = 'Zeke Create' },
    { '<leader>za', desc = 'Zeke Analyze' },
  },
  opts = {
    cmd = 'zeke',
    auto_reload = true,
  }
}
```

## Kickstart.nvim Integration

For users of kickstart.nvim, add this to your `lua/custom/plugins/init.lua`:

```lua
return {
  -- Zeke AI Assistant
  {
    'ghostkellz/zeke.nvim',
    cmd = {
      'ZekeChat',
      'ZekeEdit', 
      'ZekeExplain',
      'ZekeCreate',
      'ZekeAnalyze'
    },
    keys = {
      { '<leader>zc', mode = 'n', desc = '[Z]eke [C]hat' },
      { '<leader>ze', mode = 'n', desc = '[Z]eke [E]dit' },
      { '<leader>zx', mode = 'n', desc = '[Z]eke E[x]plain' },
      { '<leader>zf', mode = 'n', desc = '[Z]eke Create [F]ile' },
      { '<leader>za', mode = 'n', desc = '[Z]eke [A]nalyze' },
    },
    config = function()
      require('zeke').setup({
        cmd = 'zeke',
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
}
```

## Advanced Configuration

### Conditional Loading
```lua
{
  'ghostkellz/zeke.nvim',
  cmd = { 'ZekeChat', 'ZekeEdit', 'ZekeExplain', 'ZekeCreate', 'ZekeAnalyze' },
  keys = {
    { '<leader>zc', desc = 'Zeke Chat' },
    { '<leader>ze', desc = 'Zeke Edit' },
    { '<leader>zx', desc = 'Zeke Explain' },
    { '<leader>zf', desc = 'Zeke Create' },
    { '<leader>za', desc = 'Zeke Analyze' },
  },
  cond = function()
    -- Only load if zeke CLI is available
    return vim.fn.executable('zeke') == 1
  end,
  opts = {
    cmd = 'zeke',
    auto_reload = true,
  }
}
```

### Custom Binary Path
```lua
{
  'ghostkellz/zeke.nvim',
  cmd = { 'ZekeChat', 'ZekeEdit', 'ZekeExplain', 'ZekeCreate', 'ZekeAnalyze' },
  keys = {
    { '<leader>zc', desc = 'Zeke Chat' },
    { '<leader>ze', desc = 'Zeke Edit' },
    { '<leader>zx', desc = 'Zeke Explain' },
    { '<leader>zf', desc = 'Zeke Create' },
    { '<leader>za', desc = 'Zeke Analyze' },
  },
  opts = {
    cmd = vim.fn.expand('~/.local/bin/zeke'),
    auto_reload = true,
  }
}
```

### Development Mode
```lua
{
  'ghostkellz/zeke.nvim',
  dev = true, -- Use local development version
  cmd = { 'ZekeChat', 'ZekeEdit', 'ZekeExplain', 'ZekeCreate', 'ZekeAnalyze' },
  keys = {
    { '<leader>zc', desc = 'Zeke Chat' },
    { '<leader>ze', desc = 'Zeke Edit' },
    { '<leader>zx', desc = 'Zeke Explain' },
    { '<leader>zf', desc = 'Zeke Create' },
    { '<leader>za', desc = 'Zeke Analyze' },
  },
  opts = {
    cmd = './zig-out/bin/zeke_nvim',
    auto_reload = true,
  }
}
```

## Optimization Features

### Lazy Loading Benefits
- **Commands**: Only loads when Zeke commands are used
- **Keymaps**: Only loads when keymaps are pressed
- **Conditional**: Only loads if CLI is available
- **No Impact**: Zero startup time impact

### Performance Optimizations
1. **Lazy Command Loading**: Commands are registered but plugin code isn't loaded until used
2. **Keymap Lazy Loading**: Keymaps are defined but handlers aren't loaded until pressed
3. **Conditional Loading**: Plugin won't load if CLI isn't available
4. **JSON Parsing**: Minimal overhead with native vim.json
5. **Async Operations**: Non-blocking CLI execution

## Integration with Other Plugins

### With nvim-tree
```lua
{
  'ghostkellz/zeke.nvim',
  cmd = { 'ZekeChat', 'ZekeEdit', 'ZekeExplain', 'ZekeCreate', 'ZekeAnalyze' },
  keys = {
    { '<leader>zc', desc = 'Zeke Chat' },
    { '<leader>ze', desc = 'Zeke Edit' },
    { '<leader>zx', desc = 'Zeke Explain' },
    { '<leader>zf', desc = 'Zeke Create' },
    { '<leader>za', desc = 'Zeke Analyze' },
  },
  dependencies = {
    'nvim-tree/nvim-tree.lua', -- For file tree integration
  },
  opts = {
    cmd = 'zeke',
    auto_reload = true,
  }
}
```

### With Telescope
```lua
{
  'ghostkellz/zeke.nvim',
  cmd = { 'ZekeChat', 'ZekeEdit', 'ZekeExplain', 'ZekeCreate', 'ZekeAnalyze' },
  keys = {
    { '<leader>zc', desc = 'Zeke Chat' },
    { '<leader>ze', desc = 'Zeke Edit' },
    { '<leader>zx', desc = 'Zeke Explain' },
    { '<leader>zf', desc = 'Zeke Create' },
    { '<leader>za', desc = 'Zeke Analyze' },
  },
  dependencies = {
    'nvim-telescope/telescope.nvim', -- For fuzzy finding
  },
  opts = {
    cmd = 'zeke',
    auto_reload = true,
  }
}
```

## Troubleshooting

### Plugin not loading
- Check if `zeke` CLI is in PATH: `:echo executable('zeke')`
- Verify lazy.nvim configuration syntax
- Check for keymap conflicts

### Performance Issues
- Ensure `cmd` and `keys` are properly configured for lazy loading
- Check CLI response times with `:ZekeChat test`
- Monitor startup time with `:Lazy profile`

## Examples

### Full kickstart.nvim integration
```lua
-- In your kickstart config
return {
  {
    'ghostkellz/zeke.nvim',
    cmd = { 'ZekeChat', 'ZekeEdit', 'ZekeExplain', 'ZekeCreate', 'ZekeAnalyze' },
    keys = {
      { '<leader>zc', mode = 'n', desc = '[Z]eke [C]hat' },
      { '<leader>ze', mode = 'n', desc = '[Z]eke [E]dit' },
      { '<leader>zx', mode = 'n', desc = '[Z]eke E[x]plain' },
      { '<leader>zf', mode = 'n', desc = '[Z]eke Create [F]ile' },
      { '<leader>za', mode = 'n', desc = '[Z]eke [A]nalyze' },
    },
    cond = function()
      return vim.fn.executable('zeke') == 1
    end,
    config = function()
      require('zeke').setup({
        cmd = 'zeke',
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
}
```