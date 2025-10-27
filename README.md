<div align="center">
  <img src="assets/icons/zeke-nvim.png" alt="Zeke Nvim" width="128" height="128">
  <h1>zeke.nvim</h1>
</div>

[![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-f7a41d?logo=zig)](https://ziglang.org/)
[![Zig Version](https://img.shields.io/badge/Zig-0.16.0--dev-orange?logo=zig)](https://ziglang.org/)
[![Neovim](https://img.shields.io/badge/Neovim-0.9+-green?logo=neovim)](https://neovim.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/release/ghostkellz/zeke.nvim.svg)](https://github.com/ghostkellz/zeke.nvim/releases)
[![GitHub stars](https://img.shields.io/github/stars/ghostkellz/zeke.nvim)](https://github.com/ghostkellz/zeke.nvim/stargazers)

A powerful Neovim plugin for the Zeke AI platform - your Claude Code alternative.

🚀 **Refactored to use Zeke CLI v0.3.0**: Simple, fast, and no Zig compilation needed!

## ✨ Features

### Core AI Functionality
- 🤖 **7 AI Providers**: OpenAI, Claude, xAI, Google, Azure, Ollama, GitHub Copilot
- ⚡ **CLI-Based**: Direct integration with Zeke CLI v0.3.0
- 💬 **Interactive Chat**: Floating window responses
- 📝 **Intelligent Editing**: Context-aware code editing with diff preview
- 🌊 **Streaming Support**: Real-time streaming responses
- 🎯 **Code Analysis**: Quality, performance, and security analysis

### Advanced Features (NEW!)
- 🎯 **Visual Selection Tracking**: Real-time selection monitoring and AI context
- 📊 **Native Diff Management**: Side-by-side diff views with accept/reject controls
- 🌳 **File Tree Integration**: Works with nvim-tree, neo-tree, oil.nvim, mini.files
- 📋 **Visual Command Support**: Send visual selections directly to AI
- 🔧 **Comprehensive Logging**: Debug and monitor plugin activity with configurable levels
- 📱 **Enhanced Terminal**: Multiple providers with smart focus management
- 👻 **Ghostlang Ready**: Future integration with Ghostlang scripting and Grim editor

### 🎨 Production Polish (v1-Ready!)
- ⚡ **Retry Logic**: Exponential backoff for rate limits (429) and server errors (5xx)
- 🚫 **Request Cancellation**: Press ESC to cancel any active AI request
- 📐 **Visual Range Support**: All prompt commands work on visual selections (`:ZekeFix`, `:ZekeOptimize`, etc.)
- 🎯 **Model Picker**: Beautiful UI showing `auto`, `fast`, `smart` aliases with OMEN routing
- 💾 **Auto-Backups**: Files automatically backed up to `~/.cache/zeke/backups/` before edits
- ⚠️ **Safety Rails**: Warnings for large inputs (>4000 tokens) and large changes (>50 lines)
- 🔍 **Request Tracking**: Every API call gets unique ID, failed requests saved for debugging
- 📊 **Token Estimation**: See approximate costs before sending requests

See [POLISH_FEATURES.md](POLISH_FEATURES.md) for complete details!

### Infrastructure
- 📁 **Workspace Context**: File tree integration and project awareness
- 🔍 **Smart Search**: Workspace file indexing and fuzzy search
- 📚 **Context Management**: Multi-file context with smart prompting
- 📦 **Task Management**: Background processing and cancellation
- 🔧 **Highly Configurable**: Extensive customization options
- 🚀 **WebSocket Server**: Built-in async WebSocket server for real-time communication
- 🔄 **Auto-Reload**: Automatically reload files when Zeke makes changes

## 📦 Installation

### Prerequisites

1. **Install Zeke CLI** (required):
```bash
cd /path/to/zeke
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/zeke /usr/local/bin/
```

2. **Configure Zeke**:
```bash
mkdir -p ~/.config/zeke
cp zeke.toml.example ~/.config/zeke/zeke.toml
# Edit with your API keys
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "ghostkellz/zeke.nvim",
  -- No build step needed! Just install the Zeke CLI
  config = function()
    require("zeke").setup({
      -- your configuration
    })
  end,
}
```


### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'ghostkellz/zeke.nvim',
  run = 'zig build -Doptimize=ReleaseSafe',
  requires = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('zeke').setup({
      -- your configuration
    })
  end
}
```


## 📋 Requirements

- Neovim 0.9+
- **Zeke CLI v0.3.0+** - [Install from GitHub](https://github.com/ghostkellz/zeke)
- API keys for AI providers configured in `~/.config/zeke/zeke.toml`

## 🔌 Setup

### 1. Configure API Keys

Configure your AI provider API keys in Zeke's config file (`~/.config/zeke/zeke.toml`):

```toml
[default]
provider = "ollama"
model = "qwen2.5-coder:7b"

[providers.openai]
enabled = true
model = "gpt-4-turbo"

[providers.claude]
enabled = true
model = "claude-3-5-sonnet-20241022"

[providers.ollama]
enabled = true
model = "qwen2.5-coder:7b"
host = "http://localhost:11434"
```

Or use the `zeke auth` command:
```bash
zeke auth openai sk-...
zeke auth claude ...
```

## ⚙️ Configuration

```lua
require('zeke').setup({
  -- CLI configuration (no HTTP needed!)
  -- Plugin calls: vim.fn.system('zeke chat "..."')

  -- Default model (reads from ~/.config/zeke/zeke.toml)
  default_model = 'smart',  -- 'smart', 'fast', 'auto', etc.

  -- UI settings
  auto_reload = true,

  -- Keymaps
  keymaps = {
    chat = '<leader>zc',
    edit = '<leader>ze',
    explain = '<leader>zx',
    create = '<leader>zn',
    analyze = '<leader>za',
    models = '<leader>zm',
    tasks = '<leader>zt',
    chat_stream = '<leader>zs',
  },

  -- Enable selection tracking (NEW!)
  track_selection = true,

  -- Logging configuration (NEW!)
  logger = {
    level = "INFO", -- DEBUG, INFO, WARN, ERROR
    file = "~/.cache/nvim/zeke.log",
    show_timestamp = true,
  },

  -- Selection tracking settings (NEW!)
  selection = {
    debounce_ms = 100,
    visual_demotion_delay_ms = 50,
  },

  -- Diff management (NEW!)
  diff = {
    keep_terminal_focus = false,    -- Stay in terminal after opening diff
    open_in_new_tab = false,        -- Open diffs in new tabs
    auto_close_on_accept = true,    -- Auto-close after accepting
    show_diff_stats = true,         -- Show diff statistics
    vertical_split = true,          -- Use vertical splits
  },

  -- Ghostlang integration (FUTURE!)
  ghostlang = {
    auto_detect = true,             -- Auto-detect Grim editor mode
    script_dirs = { ".zeke", "scripts" },
    fallback_to_lua = true,         -- Use Lua when Ghostlang unavailable
  },
})
```

### Architecture

zeke.nvim uses the **Zeke CLI** for all AI operations:

```
┌─────────────────────────┐
│      Neovim (Lua)       │
│   - Commands            │
│   - CLI Wrapper         │
│   - UI/Chat             │
└────────┬────────────────┘
         │ vim.fn.system('zeke ...')
    ┌────▼──────────────────┐
    │  Zeke CLI v0.3.0      │ ✅ Production-ready
    │  - chat, explain      │
    │  - provider switch    │
    │  - file operations    │
    └────────┬──────────────┘
             │
      ┌──────▼──────────────┐
      │   AI Providers      │
      │  - OpenAI, Claude   │
      │  - xAI, Google      │
      │  - Ollama, Copilot  │
      └─────────────────────┘
```

## 🎮 Commands

### Core AI Commands
| Command | Description |
|---------|-------------|
| `:ZekeChat [message]` | Chat with AI (opens floating UI if no message) |
| `:ZekeEdit [instruction]` | Edit current buffer with AI (shows diff) |
| `:ZekeExplain` | Explain current buffer code |
| `:ZekeCreate [description]` | Create new file with AI |
| `:ZekeAnalyze [type]` | Analyze code (quality/performance/security) |
| `:ZekeChatStream [message]` | Streaming chat |

### UI & Chat Commands
| Command | Description |
|---------|-------------|
| `:ZekeToggleChat` | Toggle floating chat window |
| `:ZekeSaveConversation` | Save current conversation to history |
| `:ZekeLoadConversation` | Load conversation from history |

### Selection & Visual Commands (NEW!)
| Command | Description |
|---------|-------------|
| `:ZekeSend` | Send visual selection to AI (works with range) |
| `:ZekeTreeAdd` | Add selected files from file tree to AI context |

### Diff Management (NEW!)
| Command | Description |
|---------|-------------|
| `:ZekeDiffAccept` | Accept current diff changes |
| `:ZekeDiffReject` | Reject current diff changes |
| `:ZekeDiffClose` | Close all diff views |

### Terminal Control (NEW!)
| Command | Description |
|---------|-------------|
| `:ZekeTerminal` | Toggle Zeke terminal |
| `:ZekeFocus` | Smart focus/toggle terminal |

### Context Management
| Command | Description |
|---------|-------------|
| `:ZekeAddFile` | Add file to context (with picker) |
| `:ZekeAddCurrent` | Add current file to context |
| `:ZekeAddSelection` | Add current selection to context |
| `:ZekeShowContext` | Show context summary |
| `:ZekeClearContext` | Clear all context |
| `:ZekeContextFiles` | Show and manage context files |
| `:ZekeSearch [query]` | Search workspace files |

### Model & Provider Management
| Command | Description |
|---------|-------------|
| `:ZekeModels` | List available models |
| `:ZekeSetModel [model]` | Set active model |
| `:ZekeCurrentModel` | Show current model |
| `:ZekeSetProvider [provider]` | Switch AI provider |

### Task Management
| Command | Description |
|---------|-------------|
| `:ZekeTasks` | List active tasks |
| `:ZekeCancelTask [id]` | Cancel specific task |
| `:ZekeCancelAll` | Cancel all tasks |

### Utility Commands (NEW!)
| Command | Description |
|---------|-------------|
| `:ZekeLogLevel [level]` | Get or set logging level (DEBUG/INFO/WARN/ERROR) |
| `:ZekeScript [name]` | Execute Ghostlang script (future) |
| `:ZekeNewScript [name]` | Create new script template (future) |

## 🔑 Default Keymaps

| Keymap | Action |
|--------|--------|
| `<leader>zc` | Chat with AI |
| `<leader>ze` | Edit buffer |
| `<leader>zx` | Explain code |
| `<leader>zn` | Create new file |
| `<leader>za` | Analyze code |
| `<leader>zm` | List models |
| `<leader>zt` | List tasks |
| `<leader>zs` | Streaming chat |

## 🌍 Environment Variables

Set these environment variables for API access:

```bash
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="..."
export GITHUB_TOKEN="ghp_..."
export OLLAMA_HOST="http://localhost:11434"  # Optional, defaults to this
```

## 🎯 Usage Examples (NEW FEATURES!)

### Smart Selection Workflow
```lua
-- 1. Select code visually in any buffer
-- 2. Use :ZekeSend to send selection to AI
-- 3. Or use range commands: :5,15ZekeSend

-- Example: Select a function and ask AI to optimize it
-- Visual mode -> :ZekeSend
```

### File Tree Integration
```lua
-- Works with nvim-tree, neo-tree, oil.nvim, mini.files:
-- 1. Navigate to your file explorer
-- 2. Select files (mark in nvim-tree, visual selection in others)
-- 3. Run :ZekeTreeAdd to add them to AI context
-- 4. Chat with AI about the selected files
```

### Diff Management Workflow
```lua
-- After AI suggests code changes:
-- 1. Zeke automatically opens a diff view
-- 2. Review changes with ]c and [c (next/prev change)
-- 3. Use :ZekeDiffAccept to apply changes
-- 4. Or :ZekeDiffReject to discard them
-- 5. Use :ZekeDiffClose to close all diff views
```

### Advanced Logging & Debugging
```lua
-- Enable debug mode for troubleshooting
:ZekeLogLevel DEBUG

-- View logs in terminal
:terminal tail -f ~/.cache/nvim/zeke.log

-- Reset to normal logging
:ZekeLogLevel INFO
```

### Future: Ghostlang Integration
```lua
-- When Ghostlang and Grim editor are available:
:ZekeScript my_custom_workflow     -- Execute custom scripts
:ZekeNewScript ai_helper          -- Create new script templates

-- Scripts will be stored in .zeke/ or scripts/ directories
-- Automatic fallback to Lua when Ghostlang unavailable
```

## 🛠️ Building from Source

```bash
# Clone the repository
git clone https://github.com/ghostkellz/zeke.nvim.git
cd zeke.nvim

# Build the Zig executable
zig build -Doptimize=ReleaseSafe

# The compiled binary will be at:
# zig-out/bin/zeke_nvim (Linux/macOS)
# zig-out/bin/zeke_nvim.exe (Windows)

# Run tests (optional)
zig build test
```

## 📚 API Usage

```lua
local zeke = require('zeke')

-- Core AI functions
zeke.chat("Explain async/await in Rust")
zeke.edit("Add error handling to this function")
zeke.explain()
zeke.create("REST API client in Rust")
zeke.analyze('security')

-- UI functions
zeke.toggle_chat()
zeke.save_conversation()
zeke.list_conversations()

-- Context management
zeke.add_current_file_to_context()
zeke.add_selection_to_context()
zeke.show_context()

-- NEW: Selection management
zeke.selection.send_visual_selection()
zeke.selection.get_latest_selection()
zeke.selection.send_at_mention_for_visual_selection(line1, line2)

-- NEW: Diff operations
zeke.diff.accept_current_diff()
zeke.diff.deny_current_diff()
zeke.diff.close_all_diffs()
zeke.diff.create_diff(original_file, modified_file)

-- NEW: File tree integration
zeke.integrations.get_selected_files_from_tree()
zeke.integrations.send_files_to_zeke(file_paths)

-- NEW: Logging
zeke.logger.info("context", "message")
zeke.logger.set_level("DEBUG")
zeke.logger.debug("context", "debug info")

-- NEW: Ghostlang integration (future)
zeke.ghostlang.run_script("script_name", args)
zeke.ghostlang.create_script_template("new_script")
zeke.ghostlang.is_available()
zeke.ghostlang.get_status()
zeke.clear_context()
zeke.workspace_search("config")

-- Provider management
zeke.set_provider('ollama')
zeke.list_models()
zeke.set_model('llama2')
zeke.get_current_model()

-- Task management
zeke.list_tasks()
zeke.cancel_task(1)
zeke.cancel_all_tasks()
```

## 🏗️ Architecture

```
zeke.nvim/
├── src/                 # Zig source code
│   ├── main.zig        # Main entry point
│   ├── server.zig      # WebSocket server
│   ├── ai/             # AI provider implementations
│   │   ├── openai.zig
│   │   ├── claude.zig
│   │   ├── copilot.zig
│   │   ├── ollama.zig
│   │   └── ghostllm.zig
│   ├── streaming.zig   # Streaming support
│   ├── config.zig      # Configuration handling
│   └── terminal.zig    # Terminal/task management
├── lua/                # Lua plugin code
│   └── zeke/
│       ├── init.lua    # Plugin entry point
│       ├── config.lua  # Configuration
│       ├── commands.lua # Command implementations
│       ├── terminal.lua # Terminal UI
│       └── websocket.lua # WebSocket client
├── plugin/             # Neovim plugin files
│   └── zeke.lua       # Auto-loaded commands
└── build.zig          # Zig build configuration
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Zig](https://ziglang.org) for blazing-fast performance
- Uses [zsync](https://github.com/rsepassi/zsync) for async runtime
- Inspired by [claude-code.nvim](https://github.com/anthropics/claude-code.nvim)
- Part of the [Zeke AI Platform](https://github.com/ghostkellz/zeke)

## 📞 Support

- Report issues on [GitHub Issues](https://github.com/ghostkellz/zeke.nvim/issues)
- Join our [Discord](https://discord.gg/zeke) community
- Email: ckelley@ghostkellz.sh

---

