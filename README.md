# zeke.nvim

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.8+-green.svg)](https://neovim.io)
[![Zig](https://img.shields.io/badge/Zig-0.13+-orange.svg)](https://ziglang.org)
[![GitHub release](https://img.shields.io/github/release/ghostkellz/zeke.nvim.svg)](https://github.com/ghostkellz/zeke.nvim/releases)
[![GitHub stars](https://img.shields.io/github/stars/ghostkellz/zeke.nvim)](https://github.com/ghostkellz/zeke.nvim/stargazers)

A Neovim plugin that integrates with the [Zeke CLI](https://github.com/ghostkellz/zeke) - an AI-powered development assistant built with Zig.

## ✨ Features

- **AI-Powered Code Assistance**: Chat with Zeke AI directly from Neovim
- **Code Editing**: Edit code with natural language instructions
- **Code Explanation**: Get detailed explanations of code snippets
- **Code Analysis**: Analyze code quality, security, and performance
- **File Creation**: Generate new files from descriptions
- **Floating Terminal**: Beautiful floating terminal interface
- **Auto-Reload**: Automatically reload files when Zeke makes changes

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

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

### Kickstart.nvim Integration

```lua
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
  opts = {
    cmd = 'zeke',
    auto_reload = true,
  }
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'ghostkellz/zeke.nvim',
  config = function()
    require('zeke').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'ghostkellz/zeke.nvim'

" Add to your init.vim or init.lua
lua require('zeke').setup()
```

## 🚀 Prerequisites

1. **Neovim 0.8+** - Required for floating windows and modern Lua features
2. **Zeke CLI** - Install from [ghostkellz/zeke](https://github.com/ghostkellz/zeke)

### Installing Zeke CLI

```bash
# Clone and build the Zeke CLI (Zig-based)
git clone https://github.com/ghostkellz/zeke.git
cd zeke
zig build -Doptimize=ReleaseSafe
```

Make sure the `zeke` binary is in your PATH or configure the plugin with the full path.

## 🎯 Usage

### Commands

| Command | Description |
|---------|-------------|
| `:ZekeChat [message]` | Chat with Zeke AI |
| `:ZekeEdit [instruction]` | Edit current buffer with instruction |
| `:ZekeExplain` | Explain current buffer |
| `:ZekeCreate [description]` | Create new file from description |
| `:ZekeAnalyze [type]` | Analyze code (quality/security/performance) |

### Default Keymaps

| Keymap | Action |
|--------|--------|
| `<leader>zc` | Chat with Zeke |
| `<leader>ze` | Edit current buffer |
| `<leader>zx` | Explain current buffer |
| `<leader>zf` | Create new file |
| `<leader>za` | Analyze code |

### Terminal Controls

When the Zeke terminal is open:
- `<Esc>` - Exit insert mode
- `q` - Close terminal (in normal mode)

## ⚙️ Configuration

### Default Configuration

```lua
require('zeke').setup({
  cmd = 'zeke',           -- Path to zeke binary
  auto_reload = true,     -- Auto-reload files after edits
  keymaps = {
    chat = '<leader>zc',
    edit = '<leader>ze',
    explain = '<leader>zx',
    create = '<leader>zf',
    analyze = '<leader>za'
  }
})
```

### Custom Configuration Examples

```lua
-- Minimal setup
require('zeke').setup()

-- Custom binary path
require('zeke').setup({
  cmd = '/usr/local/bin/zeke'
})

-- Disable auto-reload
require('zeke').setup({
  auto_reload = false
})

-- Custom keymaps
require('zeke').setup({
  keymaps = {
    chat = '<C-z>c',
    edit = '<C-z>e',
    explain = '<C-z>x',
    create = '<C-z>f',
    analyze = '<C-z>a'
  }
})

-- Disable all keymaps (use commands only)
require('zeke').setup({
  keymaps = {}
})
```

## 🔧 CLI Integration

The plugin expects the Zeke CLI to support these commands:

```bash
zeke nvim chat "message"
zeke nvim edit "code" "instruction"
zeke nvim explain "code"
zeke nvim create "description"
zeke nvim analyze "code" "type"
```

## 🎨 Screenshots

*Coming soon - screenshots of the floating terminal interface*

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [claude-code.nvim](https://github.com/anthropics/claude-code.nvim)
- Built with [Zig](https://ziglang.org) for the CLI backend
- Made with ❤️ for the Neovim community

## 📚 Related Projects

- [Zeke CLI](https://github.com/ghostkellz/zeke) - The Zig-based AI development assistant
- [claude-code.nvim](https://github.com/anthropics/claude-code.nvim) - Official Claude Code integration

---

**Note**: This plugin requires the Zeke CLI to be installed and accessible. Make sure to install it from the [main repository](https://github.com/ghostkellz/zeke) first.
