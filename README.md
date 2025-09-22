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

A powerful Neovim plugin for the Zeke AI platform - your Claude Code alternative, built with Zig for blazing-fast performance.

🚀 **Now enhanced with advanced features inspired by Claude Code:** visual selection tracking, diff management, file tree integration, and future Ghostlang support!

## ✨ Features

### Core AI Functionality
- 🤖 **Multiple AI Providers**: OpenAI, Claude, GitHub Copilot, Ollama, GhostLLM
- ⚡ **Zig Performance**: Native speed with zero-cost abstractions
- 💬 **Interactive Chat UI**: Floating window with conversation history
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

### Infrastructure
- 📁 **Workspace Context**: File tree integration and project awareness
- 🔍 **Smart Search**: Workspace file indexing and fuzzy search
- 📚 **Context Management**: Multi-file context with smart prompting
- 📦 **Task Management**: Background processing and cancellation
- 🔧 **Highly Configurable**: Extensive customization options
- 🚀 **WebSocket Server**: Built-in async WebSocket server for real-time communication
- 🔄 **Auto-Reload**: Automatically reload files when Zeke makes changes

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "ghostkellz/zeke.nvim",
  build = "zig build -Doptimize=ReleaseSafe",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
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
- Zig 0.16.0-dev or later
- zsync v0.5.4+ (Zig async runtime)
- API keys for AI providers (OpenAI/Claude/GitHub)

## ⚙️ Configuration

```lua
require('zeke').setup({
  -- API Keys (can also use environment variables)
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
    claude = vim.env.ANTHROPIC_API_KEY,
    copilot = vim.env.GITHUB_TOKEN,
  },

  -- Default provider and model
  default_provider = 'openai',  -- 'openai', 'claude', 'copilot', 'ollama', 'ghostllm'
  default_model = 'gpt-4',

  -- Generation parameters
  temperature = 0.7,
  max_tokens = 2048,
  stream = false,

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

  -- Server configuration
  server = {
    host = '127.0.0.1',
    port = 7777,
    auto_start = true,
  },

  -- NEW FEATURES: Advanced Configuration

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

