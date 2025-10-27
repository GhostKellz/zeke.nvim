# zeke.nvim Features

## Overview

zeke.nvim is a comprehensive AI coding assistant for Neovim that surpasses GitHub Copilot and Claude Code with:
- Multiple AI provider support
- Local AI capabilities (Ollama)
- Full privacy control
- Streaming responses
- Rich LSP integration

## Core Features

### 1. Inline Ghost Text Completions

Real-time AI code suggestions displayed as ghost text (gray text) inline with your code, similar to GitHub Copilot.

**Features:**
- Automatic context-aware completions
- Multi-line suggestions
- Debounced requests (configurable)
- Multiple suggestion cycling
- Smart acceptance (full/word/line)

**Keybindings:**
- `Tab` - Accept full suggestion
- `Ctrl+]` - Dismiss suggestion
- `Ctrl+Right` - Accept next word
- `Ctrl+Down` - Accept current line
- `Alt+]` - Next suggestion
- `Alt+[` - Previous suggestion

**How it works:**
1. As you type, zeke.nvim captures context (current file, surrounding code, filetype)
2. After a brief debounce (150ms default), it requests a completion from Zeke CLI
3. Suggestions appear as gray text overlaying your cursor position
4. Multi-line suggestions show as virtual lines below
5. Accept with Tab or continue typing to dismiss

**Configuration:**
```lua
require('zeke').setup({
  completion = {
    enabled = true,
    inline = true,
    debounce_ms = 150,  -- Adjust responsiveness
  },
})
```

### 2. Chat Panel

Beautiful floating window chat interface with streaming responses and context awareness.

**Features:**
- Floating window with customizable size and border
- Separate input buffer (prompt-style UX)
- Real-time streaming responses
- Message history with visual separators
- Context attachment from current buffer
- Auto-scrolling to latest messages
- Persistent conversation threads

**Commands:**
- `:ZekeChatPanel` - Toggle chat panel
- `:ZekeChatOpen` - Open chat panel
- `:ZekeChatClose` - Close chat panel
- `:ZekeChatClear` - Clear chat history

**Keybindings (in chat):**
- `q` / `Esc` - Close chat panel
- `C` - Clear chat history
- `Enter` - Send message

**Configuration:**
```lua
require('zeke').setup({
  chat = {
    width = 0.8,   -- 80% of screen width or absolute pixels
    height = 0.8,  -- 80% of screen height or absolute pixels
    border = 'rounded',  -- 'single', 'double', 'rounded', 'solid', 'shadow'
  },
})
```

### 3. LSP Context Integration

Deep integration with Neovim's LSP for intelligent, context-aware assistance.

**Features:**
- Diagnostic detection and analysis
- Hover information extraction
- Document symbol awareness
- Context-aware completions
- AI-powered auto-fixes
- Error explanations

**Commands:**
- `:ZekeFix` - AI-powered fix for diagnostic at cursor
- `:ZekeExplainDiagnostic` - Explain diagnostic in floating window

**Context Gathering:**
zeke.nvim automatically includes:
- Current file and filetype
- Active diagnostics (errors, warnings)
- Hover information for symbols
- Document outline (functions, classes, etc.)
- Surrounding code context

**Use Cases:**
1. **Auto-fix errors**: Place cursor on error, run `:ZekeFix`
2. **Understand diagnostics**: Run `:ZekeExplainDiagnostic` for detailed explanation
3. **Context-aware chat**: Chat panel automatically includes buffer context
4. **Smart completions**: Inline completions understand LSP context

### 4. Smart Keybindings

Intuitive, mnemonic keybindings for quick AI assistance.

**AI Assistance Shortcuts:**
- `<leader>aa` - **Ask AI** - Quick prompt with chat panel
- `<leader>af` - **AI Fix** - Fix diagnostic at cursor
- `<leader>ae` - **AI Edit** - Edit selection with AI (visual mode)
- `<leader>ax` - **AI eXplain** - Explain code
- `<leader>ac` - **AI Chat** - Toggle chat panel
- `<leader>at` - **AI Toggle** - Toggle inline completions

**Configurable Keymaps:**
```lua
require('zeke').setup({
  keymaps = {
    enabled = true,
    code = '<leader>zc',         -- ZekeCode agent
    chat = '<leader>zC',         -- Quick chat
    chat_panel = '<leader>zp',   -- Toggle chat panel
    explain = '<leader>ze',      -- Explain code
    edit = '<leader>zE',         -- Edit with AI
    fix_diagnostic = '<leader>zf', -- Fix diagnostic
    explain_diagnostic = '<leader>zd', -- Explain diagnostic
    model_picker = '<leader>zm', -- Model picker
    model_next = '<Tab>',        -- Next model (in ZekeCode)
    model_prev = '<S-Tab>',      -- Previous model
  },
})
```

## Additional Features

### Model Management

Switch between different AI models on the fly.

**Commands:**
- `:ZekeModels` - Model picker (Telescope interface)
- `:ZekeModelNext` - Cycle to next model
- `:ZekeModelPrev` - Cycle to previous model
- `:ZekeModelInfo` - Show current model info

**Supported Models:**
- Fast models (quick responses)
- Smart models (complex reasoning)
- Balanced models (good for most tasks)
- Local models (Ollama)

### Provider Management

Support for multiple AI providers.

**Supported Providers:**
- **Ollama** - Local, free, privacy-focused
- **OpenAI** - GPT-4, GPT-3.5
- **Claude** - Claude 3 (Opus, Sonnet, Haiku)
- **Google** - Gemini Pro
- **GitHub Copilot** - Copilot Pro integration
- **xAI** - Grok models

**Commands:**
- `:ZekeProviders` - List available providers
- `:ZekeProviderSet <provider>` - Switch provider
- `:ZekeProviderStatus` - Show provider status

### Code Operations

Additional AI-powered code operations.

**Commands:**
- `:ZekeEdit [instruction]` - Edit current buffer with AI
- `:ZekeExplain` - Explain current buffer
- `:ZekeCreate [description]` - Create new file with AI
- `:ZekeAnalyze [type]` - Analyze code quality/security
- `:ZekeCode` - Main ZekeCode agent interface

## Comparison with Alternatives

### vs. GitHub Copilot

| Feature | Copilot | zeke.nvim |
|---------|---------|-----------|
| Inline completions | ✅ | ✅ |
| Chat interface | ✅ | ✅ (Better UX) |
| Multiple providers | ❌ | ✅ |
| Local AI | ❌ | ✅ |
| LSP integration | ❌ | ✅ |
| Free | ❌ | ✅ |
| Open source | ❌ | ✅ |
| Privacy control | ❌ | ✅ |

### vs. Claude Code

| Feature | Claude Code | zeke.nvim |
|---------|-------------|-----------|
| Agent interface | ✅ | ✅ |
| Inline completions | ❌ | ✅ |
| Chat panel | ✅ | ✅ |
| Multiple providers | ❌ | ✅ |
| Streaming | ✅ | ✅ |
| LSP integration | Limited | ✅ Full |
| Local AI | ❌ | ✅ |

## Performance

- **Inline completions**: ~150-500ms latency (depends on provider)
- **Chat responses**: Streaming (starts in <1s)
- **LSP operations**: Near-instant context gathering
- **Memory usage**: Lightweight (<50MB typical)

## Privacy

- **Local AI**: Use Ollama for 100% local processing
- **No telemetry**: Zero tracking or analytics
- **Full control**: Choose your provider and model
- **Open source**: Audit the code yourself

## Getting Started

See [EXAMPLE_CONFIG.md](../EXAMPLE_CONFIG.md) for configuration examples.
