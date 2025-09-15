# 📚 Zeke.nvim Documentation

Welcome to the comprehensive documentation for **zeke.nvim** - the powerful Claude Code alternative built with Rust performance and modern Neovim features.

## 📖 Table of Contents

- [🚀 Quick Start](#-quick-start)
- [⚙️ Configuration](#️-configuration)
- [🤖 AI Providers](#-ai-providers)
- [💬 Chat Interface](#-chat-interface)
- [📁 Workspace Context](#-workspace-context)
- [🔧 Diff View](#-diff-view)
- [🎮 Commands Reference](#-commands-reference)
- [🔑 Keymaps](#-keymaps)
- [🛠️ Advanced Usage](#️-advanced-usage)
- [🔍 Troubleshooting](#-troubleshooting)
- [📋 FAQ](#-faq)

## 🚀 Quick Start

### Prerequisites

- **Neovim 0.9+**
- **Rust 2024** (for building)
- **AI Provider API Keys** (OpenAI, Claude, GitHub, or local Ollama)

### Installation

#### Using lazy.nvim (Recommended)

```lua
{
  "ghostkellz/zeke.nvim",
  build = "cargo build --release",
  dependencies = {
    "nvim-lua/plenary.nvim",  -- Required for HTTP requests
  },
  event = "VeryLazy",
  config = function()
    require("zeke").setup({
      -- your configuration here
    })
  end,
}
```

#### Using packer.nvim

```lua
use {
  'ghostkellz/zeke.nvim',
  run = 'cargo build --release',
  requires = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('zeke').setup({
      -- your configuration here
    })
  end
}
```

### Basic Setup

```lua
require('zeke').setup({
  default_provider = 'openai',  -- or 'claude', 'copilot', 'ollama'
  default_model = 'gpt-4',
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
    claude = vim.env.ANTHROPIC_API_KEY,
  },
})
```

### First Steps

1. **Set API Keys**: Add to your shell profile
   ```bash
   export OPENAI_API_KEY="sk-..."
   export ANTHROPIC_API_KEY="..."
   ```

2. **Test Chat**: `:ZekeChat Hello, world!`

3. **Open Chat UI**: `:ZekeToggleChat`

4. **Add Context**: `:ZekeAddCurrent` to add current file

## ⚙️ Configuration

### Complete Configuration Example

```lua
require('zeke').setup({
  -- AI Provider Settings
  default_provider = 'openai',
  default_model = 'gpt-4',

  -- API Keys (environment variables recommended)
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
    claude = vim.env.ANTHROPIC_API_KEY,
    copilot = vim.env.GITHUB_TOKEN,
  },

  -- Generation Parameters
  temperature = 0.7,
  max_tokens = 2048,
  stream = false,

  -- UI Settings
  auto_reload = true,

  -- Keymaps (set to false to disable, or customize)
  keymaps = {
    chat = '<leader>zc',
    edit = '<leader>ze',
    explain = '<leader>zx',
    create = '<leader>zn',
    analyze = '<leader>za',
    models = '<leader>zm',
    tasks = '<leader>zt',
    chat_stream = '<leader>zs',

    -- New UI keymaps
    toggle_chat = '<leader>zt',
    add_file = '<leader>zf',
    add_current = '<leader>zac',
    show_context = '<leader>zsc',
    clear_context = '<leader>zcc',
  },

  -- Server Configuration (for future HTTP API)
  server = {
    host = '127.0.0.1',
    port = 7777,
    auto_start = true,
  },

  -- Workspace Settings
  workspace = {
    auto_scan = true,
    include_patterns = {
      '*.lua', '*.rs', '*.py', '*.js', '*.ts',
      '*.go', '*.c', '*.cpp', '*.java', '*.kt'
    },
    exclude_patterns = {
      '*/node_modules/*', '*/.git/*', '*/target/*'
    },
  },

  -- UI Customization
  ui = {
    chat = {
      width = 0.8,          -- 80% of screen width
      height = 0.8,         -- 80% of screen height
      border = 'rounded',   -- 'single', 'double', 'rounded', 'solid'
      title = ' Zeke Chat ',
    },
    diff = {
      width = 0.9,
      height = 0.8,
      border = 'rounded',
    },
  },
})
```

### Environment Variables

Create a `.env` file or add to your shell profile:

```bash
# Required for respective providers
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="..."
export GITHUB_TOKEN="ghp_..."

# Optional Ollama configuration
export OLLAMA_HOST="http://localhost:11434"

# Optional: Zeke-specific settings
export ZEKE_DEFAULT_PROVIDER="ollama"
export ZEKE_DEFAULT_MODEL="llama2"
```

## 🤖 AI Providers

### OpenAI

**Setup:**
1. Get API key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. Set environment variable: `export OPENAI_API_KEY="sk-..."`

**Available Models:**
- `gpt-4` (recommended)
- `gpt-4-turbo`
- `gpt-3.5-turbo`
- `gpt-3.5-turbo-16k`

**Configuration:**
```lua
require('zeke').setup({
  default_provider = 'openai',
  default_model = 'gpt-4',
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
  },
})
```

### Claude (Anthropic)

**Setup:**
1. Get API key from [Anthropic Console](https://console.anthropic.com/)
2. Set environment variable: `export ANTHROPIC_API_KEY="..."`

**Available Models:**
- `claude-3-5-sonnet-20241022` (recommended)
- `claude-3-5-haiku-20241022`
- `claude-3-opus-20240229`
- `claude-3-sonnet-20240229`

**Configuration:**
```lua
require('zeke').setup({
  default_provider = 'claude',
  default_model = 'claude-3-5-sonnet-20241022',
  api_keys = {
    claude = vim.env.ANTHROPIC_API_KEY,
  },
})
```

### GitHub Copilot

**Setup:**
1. Install GitHub CLI: `gh auth login`
2. Get token: `gh auth token`
3. Set environment variable: `export GITHUB_TOKEN="ghp_..."`

**Configuration:**
```lua
require('zeke').setup({
  default_provider = 'copilot',
  api_keys = {
    copilot = vim.env.GITHUB_TOKEN,
  },
})
```

### Ollama (Local Models)

**Setup:**
1. Install [Ollama](https://ollama.ai/)
2. Start service: `ollama serve`
3. Pull a model: `ollama pull llama2`

**Available Models:**
- `llama2`, `llama2:13b`, `llama2:70b`
- `codellama`, `codellama:13b`, `codellama:34b`
- `mistral`, `mixtral`
- `qwen`, `dolphin-mixtral`

**Configuration:**
```lua
require('zeke').setup({
  default_provider = 'ollama',
  default_model = 'codellama',  -- Great for coding tasks
  -- No API key needed for local models
})

-- Optional: Custom Ollama host
vim.env.OLLAMA_HOST = "http://192.168.1.100:11434"
```

### Switching Providers

```lua
-- Via command
:ZekeSetProvider ollama

-- Via API
require('zeke').set_provider('claude')

-- Via configuration
require('zeke').setup({
  default_provider = 'claude',
})
```

## 💬 Chat Interface

### Opening Chat

```lua
-- Open floating chat window
:ZekeToggleChat

-- Or via keymap (default <leader>zt)
-- Or via API
require('zeke').toggle_chat()
```

### Chat Features

#### **Floating Window Interface**
- **Input Area**: Type your message
- **Chat Display**: See conversation history
- **Markdown Rendering**: Code blocks, formatting
- **Auto-scroll**: Always shows latest messages

#### **Keyboard Shortcuts in Chat**
- `Ctrl+S`: Send message
- `Esc`: Close chat
- `Ctrl+C`: Clear conversation
- `q`: Close chat (in normal mode)

#### **Conversation Management**
```lua
-- Save current conversation
:ZekeSaveConversation

-- Load previous conversation
:ZekeLoadConversation

-- Via API
require('zeke').save_conversation()
require('zeke').list_conversations()
```

### Chat Workflow Example

```lua
-- 1. Open chat
require('zeke').toggle_chat()

-- 2. Add context files
require('zeke').add_current_file_to_context()

-- 3. Chat with context
-- Type: "Explain the main function in this file"

-- 4. Save conversation for later
require('zeke').save_conversation()
```

## 📁 Workspace Context

### Understanding Context

**Context** is the collection of files and code that Zeke uses to understand your project and provide better responses.

### Adding Context

#### **Add Current File**
```lua
:ZekeAddCurrent
-- Or
require('zeke').add_current_file_to_context()
```

#### **Add Any File**
```lua
:ZekeAddFile  -- Opens file picker
-- Or
require('zeke').add_file_to_context()
```

#### **Add Selection**
```lua
-- 1. Select code in visual mode
-- 2. Run command
:ZekeAddSelection
-- Or
require('zeke').add_selection_to_context()
```

#### **Search and Add Files**
```lua
:ZekeSearch config  -- Search for files containing "config"
-- Or
require('zeke').workspace_search("config")
```

### Managing Context

#### **View Context**
```lua
:ZekeShowContext    -- Show summary
:ZekeContextFiles   -- Show and manage files
```

#### **Clear Context**
```lua
:ZekeClearContext
-- Or
require('zeke').clear_context()
```

### Context Best Practices

1. **Start Small**: Add 2-3 relevant files
2. **Add Related Files**: Include interfaces, configs, tests
3. **Use Selections**: For large files, add specific functions
4. **Clean Regularly**: Remove irrelevant context

### Example Workflow

```lua
-- Working on a React component
require('zeke').add_current_file_to_context()        -- MyComponent.tsx
require('zeke').workspace_search("types")            -- Add type definitions
require('zeke').workspace_search("api")              -- Add API client

-- Check context
require('zeke').show_context()
-- Output: "3 files, 245 lines, 8.2KB"

-- Chat with full context
require('zeke').chat("How can I optimize this component?")
```

## 🔧 Diff View

### How Diff View Works

When you use `:ZekeEdit`, Zeke shows a **visual diff** instead of directly applying changes:

1. **Shows Changes**: Side-by-side comparison
2. **Accept/Reject**: Review before applying
3. **Safe Editing**: No accidental overwrites

### Using Diff View

#### **Trigger Diff**
```lua
:ZekeEdit "Add error handling to this function"
```

#### **Diff Controls**
- `a`: **Accept** changes and apply to buffer
- `r`: **Reject** changes and discard
- `q`: **Quit** diff view
- `<Esc>`: Same as quit

### Diff Display

```
╔═══════════════════════════════════════════════════════════╗
║                      CODE DIFF VIEW                      ║
║  Press "a" to accept changes, "r" to reject, "q" to quit ║
╚═══════════════════════════════════════════════════════════╝

┌─ ORIGINAL ─────────────────┬─ MODIFIED ─────────────────┐
│  function processData(data)│+ function processData(data)│
│    return data.map(item => │    if (!data) {           │
│      item.value * 2        │+     throw new Error('...')│
│    )                       │+   }                      │
│  }                         │    return data.map(item =>│
│                            │      item.value * 2       │
│                            │    )                      │
│                            │  }                        │
└────────────────────────────┴────────────────────────────┘

Statistics:
  Original: 4 lines
  Modified: 8 lines
  Changes: +4 -0 ~1
```

### File Creation Preview

When using `:ZekeCreate`, you get a preview window:

```lua
:ZekeCreate "Create a TypeScript interface for user data"
```

**Preview Controls:**
- `s`: **Save** file with given name
- `q`: **Cancel** and discard

## 🎮 Commands Reference

### Core AI Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `:ZekeChat [message]` | `:ZekeChat "Explain this code"` | Chat with AI |
| `:ZekeEdit [instruction]` | `:ZekeEdit "Add error handling"` | Edit current buffer |
| `:ZekeExplain` | `:ZekeExplain` | Explain current buffer |
| `:ZekeCreate [description]` | `:ZekeCreate "REST API client"` | Create new file |
| `:ZekeAnalyze [type]` | `:ZekeAnalyze security` | Analyze code |

### UI Commands

| Command | Description |
|---------|-------------|
| `:ZekeToggleChat` | Toggle floating chat window |
| `:ZekeSaveConversation` | Save current chat to history |
| `:ZekeLoadConversation` | Load chat from history |

### Context Commands

| Command | Description |
|---------|-------------|
| `:ZekeAddFile` | Add file to context (picker) |
| `:ZekeAddCurrent` | Add current file to context |
| `:ZekeAddSelection` | Add visual selection to context |
| `:ZekeShowContext` | Show context summary |
| `:ZekeClearContext` | Clear all context |
| `:ZekeContextFiles` | Manage context files |
| `:ZekeSearch [query]` | Search workspace files |

### Provider Commands

| Command | Description |
|---------|-------------|
| `:ZekeSetProvider [name]` | Switch AI provider |
| `:ZekeModels` | List available models |
| `:ZekeSetModel [model]` | Set active model |
| `:ZekeCurrentModel` | Show current model |

### Task Commands

| Command | Description |
|---------|-------------|
| `:ZekeTasks` | List active background tasks |
| `:ZekeCancelTask [id]` | Cancel specific task |
| `:ZekeCancelAll` | Cancel all tasks |

### Streaming Commands

| Command | Description |
|---------|-------------|
| `:ZekeChatStream [message]` | Start streaming chat |

## 🔑 Keymaps

### Default Keymaps

| Keymap | Command | Description |
|--------|---------|-------------|
| `<leader>zc` | `:ZekeChat` | Chat with AI |
| `<leader>ze` | `:ZekeEdit` | Edit buffer |
| `<leader>zx` | `:ZekeExplain` | Explain code |
| `<leader>zn` | `:ZekeCreate` | Create new file |
| `<leader>za` | `:ZekeAnalyze` | Analyze code |
| `<leader>zm` | `:ZekeModels` | List models |
| `<leader>zt` | `:ZekeTasks` | List tasks |
| `<leader>zs` | `:ZekeChatStream` | Streaming chat |

### Custom Keymaps

```lua
require('zeke').setup({
  keymaps = {
    -- Core functions
    chat = '<C-a>c',           -- Ctrl+A, C
    edit = '<C-a>e',           -- Ctrl+A, E
    explain = '<C-a>x',        -- Ctrl+A, X

    -- Disable specific keymaps
    create = false,            -- Disable create keymap

    -- UI functions
    toggle_chat = '<leader>tc', -- Custom chat toggle

    -- Context management
    add_current = '<leader>ac', -- Add current file
    show_context = '<leader>sc', -- Show context
  },
})
```

### Additional Keymaps

```lua
-- Add custom keymaps in your config
vim.keymap.set('n', '<leader>zp', function()
  require('zeke').set_provider('ollama')
end, { desc = 'Switch to Ollama' })

vim.keymap.set('v', '<leader>ze', function()
  -- Edit selection instead of whole buffer
  require('zeke').add_selection_to_context()
  vim.ui.input({ prompt = 'Edit instruction: ' }, function(instruction)
    if instruction then
      require('zeke').edit(instruction)
    end
  end)
end, { desc = 'Edit selection with Zeke' })
```

## 🛠️ Advanced Usage

### Workflow Examples

#### **Code Review Workflow**
```lua
-- 1. Add files to review
require('zeke').add_current_file_to_context()
require('zeke').workspace_search("test")  -- Add related tests

-- 2. Analyze code
require('zeke').analyze('security')

-- 3. Chat about improvements
require('zeke').toggle_chat()
-- Type: "What security issues do you see? How can I fix them?"
```

#### **Refactoring Workflow**
```lua
-- 1. Add file to context
require('zeke').add_current_file_to_context()

-- 2. Edit with specific instruction
require('zeke').edit("Refactor this to use async/await instead of callbacks")

-- 3. Review changes in diff view
-- Press 'a' to accept or 'r' to reject

-- 4. Analyze the refactored code
require('zeke').analyze('performance')
```

#### **Learning Workflow**
```lua
-- 1. Add unfamiliar code to context
require('zeke').add_selection_to_context()  -- Select complex function

-- 2. Get explanation
require('zeke').explain()

-- 3. Ask follow-up questions
require('zeke').toggle_chat()
-- Type: "Can you show me a simpler version of this algorithm?"
```

### API Usage

#### **Programmatic Control**
```lua
local zeke = require('zeke')

-- Check if provider is available
local models = zeke.list_models()
if #models > 0 then
  print("Provider available with " .. #models .. " models")
end

-- Batch operations
zeke.add_current_file_to_context()
zeke.workspace_search("config")
zeke.workspace_search("types")

local context_summary = zeke.show_context()
print("Context: " .. context_summary)

-- Automated code review
zeke.analyze('security')
zeke.analyze('performance')
zeke.analyze('quality')
```

#### **Integration with Other Plugins**

```lua
-- Integration with telescope.nvim
vim.keymap.set('n', '<leader>zf', function()
  require('telescope.builtin').find_files({
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', function()
        local selection = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(prompt_bufnr)
        require('zeke').add_file_to_context(selection.path)
      end)
      return true
    end,
  })
end, { desc = 'Add file to Zeke context via Telescope' })

-- Integration with nvim-tree
local function on_attach(bufnr)
  local api = require('nvim-tree.api')

  vim.keymap.set('n', 'za', function()
    local node = api.tree.get_node_under_cursor()
    if node and node.type == 'file' then
      require('zeke').add_file_to_context(node.absolute_path)
    end
  end, { buffer = bufnr, desc = 'Add to Zeke context' })
end

require('nvim-tree').setup({
  on_attach = on_attach,
})
```

### Performance Tips

#### **Context Management**
```lua
-- Good: Focused context
require('zeke').add_current_file_to_context()
require('zeke').add_selection_to_context()  -- Just the relevant function

-- Avoid: Too much context
-- Don't add entire large files if you only need one function
```

#### **Provider Selection**
```lua
-- For speed: Use Ollama (local)
require('zeke').set_provider('ollama')

-- For quality: Use Claude or GPT-4
require('zeke').set_provider('claude')

-- For coding: Use specialized models
require('zeke').set_model('codellama')  -- For Ollama
```

## 🔍 Troubleshooting

### Common Issues

#### **"Zeke not initialized" Error**
```bash
# Check if build succeeded
cd ~/.local/share/nvim/lazy/zeke.nvim  # or your plugin path
cargo build --release

# Check if library exists
ls target/release/libzeke_nvim.*
```

#### **API Key Issues**
```bash
# Check environment variables
echo $OPENAI_API_KEY
echo $ANTHROPIC_API_KEY

# Test API directly
curl -H "Authorization: Bearer $OPENAI_API_KEY" \
     https://api.openai.com/v1/models
```

#### **Ollama Connection Issues**
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Start Ollama if not running
ollama serve

# Pull a model
ollama pull llama2
```

#### **UI Issues**
```lua
-- Reset UI state
require('zeke.ui').close_chat()

-- Clear all context
require('zeke').clear_context()

-- Restart plugin
require('zeke').setup({})  -- Re-run setup
```

### Debug Mode

```lua
-- Enable verbose logging
require('zeke').setup({
  debug = true,
  log_level = 'debug',
})

-- Check logs
:messages
```

### Performance Issues

```lua
-- Reduce context size
require('zeke').clear_context()

-- Use smaller models
require('zeke').set_model('gpt-3.5-turbo')  -- Instead of gpt-4

-- Disable streaming for better stability
require('zeke').setup({
  stream = false,
})
```

## 📋 FAQ

### **Q: Which AI provider should I use?**
- **OpenAI**: Best overall quality, fast responses
- **Claude**: Excellent for complex reasoning, longer context
- **Ollama**: Private, free, works offline
- **Copilot**: Good for code completion, requires GitHub

### **Q: How much context should I add?**
Start with 1-3 files (2000-5000 lines total). More context = better understanding but slower responses.

### **Q: Can I use multiple providers?**
Yes! Switch anytime with `:ZekeSetProvider <provider>`.

### **Q: Does it work offline?**
Yes, with Ollama. Install local models and set `default_provider = 'ollama'`.

### **Q: How do I save API costs?**
- Use Ollama for development
- Use smaller models (gpt-3.5-turbo vs gpt-4)
- Clear context when not needed
- Use streaming to cancel long responses

### **Q: Can I customize the UI?**
Yes! See [Configuration](#️-configuration) for UI customization options.

### **Q: How do I report bugs?**
Create an issue at [GitHub Issues](https://github.com/ghostkellz/zeke.nvim/issues) with:
- Your config
- Error messages
- Steps to reproduce

---

**Need more help?** Join our [Discord](https://discord.gg/zeke) or check the [GitHub Discussions](https://github.com/ghostkellz/zeke.nvim/discussions)!