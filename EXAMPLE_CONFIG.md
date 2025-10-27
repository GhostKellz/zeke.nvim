# zeke.nvim Configuration Examples

## Quick Start (Minimal Config)

```lua
require('zeke').setup{}
```

## Full Configuration

```lua
require('zeke').setup({
  -- Inline Completions (Ghost Text like Copilot)
  completion = {
    enabled = true,
    inline = true,
    debounce_ms = 150,
  },

  -- Chat Panel
  chat = {
    width = 0.8,  -- 80% of screen or absolute pixels
    height = 0.8,
    border = 'rounded',
  },

  -- LSP Integration
  lsp = {
    enabled = true,
    auto_fix_on_save = false,
  },

  -- Keymaps
  keymaps = {
    enabled = true,
    code = '<leader>zc',        -- ZekeCode agent
    chat = '<leader>zC',        -- Quick chat
    chat_panel = '<leader>zp',  -- Toggle chat panel
    explain = '<leader>ze',     -- Explain code
    edit = '<leader>zE',        -- Edit with AI
    fix_diagnostic = '<leader>zf', -- Fix diagnostic
    model_picker = '<leader>zm', -- Model picker
  },
})
```

## Lazy.nvim

```lua
{
  'ghostkellz/zeke.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',  -- Optional
  },
  config = function()
    require('zeke').setup({
      completion = { enabled = true },
      keymaps = { enabled = true },
    })
  end,
  keys = {
    { '<leader>zc', '<cmd>ZekeCode<cr>', desc = 'ZekeCode Agent' },
    { '<leader>zp', '<cmd>ZekeChatPanel<cr>', desc = 'Chat Panel' },
    { '<leader>zf', '<cmd>ZekeFix<cr>', desc = 'Fix Diagnostic' },
  },
  cmd = {
    'ZekeCode',
    'ZekeChatPanel',
    'ZekeEdit',
    'ZekeFix',
  },
}
```

## Key Features

### 1. Inline Ghost Text Completions
- Like GitHub Copilot
- Tab to accept, Ctrl+] to dismiss
- Ctrl+Right for word, Ctrl+Down for line
- Alt+]/[ to cycle suggestions

### 2. Chat Panel
- Floating window interface
- Streaming responses
- Context attachment
- Thread history

### 3. LSP Context Integration
- Auto-fix diagnostics: `:ZekeFix`
- Explain errors: `:ZekeExplainDiagnostic`
- Context-aware completions

### 4. Smart Keybindings
- `<leader>aa` - Ask AI
- `<leader>af` - Fix diagnostic
- `<leader>ae` - Edit selection
- `<leader>ax` - Explain code
- `<leader>ac` - Toggle chat
- `<leader>at` - Toggle completions

## Commands

- `:ZekeCode` - Main AI agent
- `:ZekeChatPanel` - Chat panel
- `:ZekeFix` - Fix diagnostic
- `:ZekeEdit` - Edit buffer
- `:ZekeExplain` - Explain code
- `:ZekeModels` - Model picker

## Requirements

1. **Zeke CLI** installed
```bash
cargo install --git https://github.com/ghostkellz/zeke
```

2. **AI Provider** configured (at least one):
   - Ollama (local, free)
   - OpenAI
   - Claude
   - Google
   - GitHub Copilot
   - xAI

3. **Configure**:
```bash
zeke config
```

