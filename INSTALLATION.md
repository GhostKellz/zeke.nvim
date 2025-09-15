# 🚀 Installation Guide

Complete step-by-step installation guide for **zeke.nvim**.

## 📋 Prerequisites

### Required

- **Neovim 0.9+**: Check with `nvim --version`
- **Rust 2024**: Install from [rustup.rs](https://rustup.rs/)
- **Git**: For cloning repositories

### Verify Prerequisites

```bash
# Check Neovim version
nvim --version
# Should show v0.9.0 or higher

# Check Rust version
rustc --version
# Should show 1.70+ with 2024 edition support

# Check Cargo
cargo --version
# Should be available with Rust
```

## 🔧 Installation Methods

### Method 1: lazy.nvim (Recommended)

Add to your `~/.config/nvim/lua/plugins/zeke.lua`:

```lua
return {
  "ghostkellz/zeke.nvim",
  build = "cargo build --release",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  event = "VeryLazy",
  keys = {
    { "<leader>zc", desc = "Zeke Chat" },
    { "<leader>ze", desc = "Zeke Edit" },
    { "<leader>zx", desc = "Zeke Explain" },
    { "<leader>zt", desc = "Toggle Zeke Chat" },
  },
  config = function()
    require("zeke").setup({
      default_provider = "openai",  -- Change as needed
      default_model = "gpt-4",
      api_keys = {
        openai = vim.env.OPENAI_API_KEY,
        claude = vim.env.ANTHROPIC_API_KEY,
      },
    })
  end,
}
```

### Method 2: packer.nvim

Add to your `plugins.lua`:

```lua
use {
  'ghostkellz/zeke.nvim',
  run = 'cargo build --release',
  requires = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('zeke').setup({
      default_provider = 'openai',
      api_keys = {
        openai = vim.env.OPENAI_API_KEY,
      },
    })
  end
}
```

### Method 3: vim-plug

Add to your `init.vim`:

```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'ghostkellz/zeke.nvim', { 'do': 'cargo build --release' }
```

Then in your `init.lua`:

```lua
require('zeke').setup({
  default_provider = 'openai',
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
  },
})
```

### Method 4: Manual Installation

```bash
# Clone the repository
cd ~/.local/share/nvim/site/pack/plugins/start/
git clone https://github.com/ghostkellz/zeke.nvim.git

# Build the Rust library
cd zeke.nvim
cargo build --release

# Also install plenary.nvim
cd ~/.local/share/nvim/site/pack/plugins/start/
git clone https://github.com/nvim-lua/plenary.nvim.git
```

Add to your `init.lua`:

```lua
require('zeke').setup({
  -- your config
})
```

## 🔑 API Key Setup

### Environment Variables (Recommended)

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
# OpenAI
export OPENAI_API_KEY="sk-..."

# Claude (Anthropic)
export ANTHROPIC_API_KEY="..."

# GitHub Copilot
export GITHUB_TOKEN="ghp_..."

# Ollama (optional)
export OLLAMA_HOST="http://localhost:11434"
```

### Using a .env file

Create `~/.config/zeke/.env`:

```bash
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=...
GITHUB_TOKEN=ghp_...
```

Load in your Neovim config:

```lua
-- Load environment variables
local env_file = vim.fn.expand('~/.config/zeke/.env')
if vim.fn.filereadable(env_file) == 1 then
  for line in io.lines(env_file) do
    local key, value = line:match('([^=]+)=(.+)')
    if key and value then
      vim.env[key] = value
    end
  end
end

require('zeke').setup({
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
    claude = vim.env.ANTHROPIC_API_KEY,
  },
})
```

### Direct Configuration (Not Recommended)

```lua
require('zeke').setup({
  api_keys = {
    openai = "sk-...",  -- Don't commit this!
    claude = "...",
  },
})
```

## 🤖 Provider-Specific Setup

### OpenAI Setup

1. **Get API Key**:
   - Go to [OpenAI Platform](https://platform.openai.com/api-keys)
   - Create new secret key
   - Copy the key (starts with `sk-`)

2. **Set Environment Variable**:
   ```bash
   export OPENAI_API_KEY="sk-your-key-here"
   ```

3. **Configure**:
   ```lua
   require('zeke').setup({
     default_provider = 'openai',
     default_model = 'gpt-4',
   })
   ```

### Claude (Anthropic) Setup

1. **Get API Key**:
   - Go to [Anthropic Console](https://console.anthropic.com/)
   - Create API key
   - Copy the key

2. **Set Environment Variable**:
   ```bash
   export ANTHROPIC_API_KEY="your-key-here"
   ```

3. **Configure**:
   ```lua
   require('zeke').setup({
     default_provider = 'claude',
     default_model = 'claude-3-5-sonnet-20241022',
   })
   ```

### GitHub Copilot Setup

1. **Install GitHub CLI**:
   ```bash
   # macOS
   brew install gh

   # Ubuntu/Debian
   sudo apt install gh

   # Windows
   winget install GitHub.cli
   ```

2. **Authenticate**:
   ```bash
   gh auth login
   ```

3. **Get Token**:
   ```bash
   gh auth token
   ```

4. **Set Environment Variable**:
   ```bash
   export GITHUB_TOKEN="ghp_your-token-here"
   ```

5. **Configure**:
   ```lua
   require('zeke').setup({
     default_provider = 'copilot',
   })
   ```

### Ollama Setup (Local Models)

1. **Install Ollama**:
   ```bash
   # macOS
   brew install ollama

   # Linux
   curl -fsSL https://ollama.ai/install.sh | sh

   # Windows
   # Download from https://ollama.ai/download
   ```

2. **Start Ollama**:
   ```bash
   ollama serve
   ```

3. **Pull Models**:
   ```bash
   # For general use
   ollama pull llama2

   # For coding (recommended)
   ollama pull codellama

   # For chat
   ollama pull mistral
   ```

4. **Configure**:
   ```lua
   require('zeke').setup({
     default_provider = 'ollama',
     default_model = 'codellama',  -- Great for coding
   })
   ```

## 🔧 Build Troubleshooting

### Common Build Issues

#### **Rust Not Found**

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Update to latest
rustup update
```

#### **Build Fails on M1 Mac**

```bash
# Install Xcode command line tools
xcode-select --install

# Set target explicitly
cd ~/.local/share/nvim/lazy/zeke.nvim
cargo build --release --target=aarch64-apple-darwin
```

#### **Build Fails on Linux**

```bash
# Install build dependencies
sudo apt update
sudo apt install build-essential pkg-config libssl-dev

# Or on RHEL/CentOS
sudo yum groupinstall "Development Tools"
sudo yum install openssl-devel
```

#### **Permission Issues**

```bash
# Fix permissions
sudo chown -R $USER:$USER ~/.local/share/nvim/
chmod -R 755 ~/.local/share/nvim/
```

### Manual Build

If automatic build fails, build manually:

```bash
# Navigate to plugin directory
cd ~/.local/share/nvim/lazy/zeke.nvim  # or your plugin path

# Clean and rebuild
cargo clean
cargo build --release

# Verify library exists
ls target/release/libzeke_nvim.*
```

### Check Installation

```lua
-- Add to your config to verify installation
vim.api.nvim_create_user_command('ZekeStatus', function()
  local ok, zeke_nvim = pcall(require, 'zeke_nvim')
  if ok then
    print("✅ Zeke Rust module loaded successfully")
  else
    print("❌ Zeke Rust module failed to load: " .. tostring(zeke_nvim))
  end

  local zeke = require('zeke')
  print("✅ Zeke Lua module loaded")

  -- Test basic functionality
  local models = zeke.list_models()
  print("📋 Available models: " .. #models)
end, {})
```

Run `:ZekeStatus` to check installation.

## 🚀 Quick Start After Installation

### 1. Restart Neovim

```bash
# Exit Neovim completely
:qa

# Restart
nvim
```

### 2. Test Basic Functionality

```lua
-- Test chat (should open floating window)
:ZekeToggleChat

-- Test with a simple message
:ZekeChat "Hello, world!"

-- Check models
:ZekeModels

-- Check current provider
:ZekeCurrentModel
```

### 3. Add Context and Test

```lua
-- Add current file to context
:ZekeAddCurrent

-- Show context
:ZekeShowContext

-- Ask about the file
:ZekeChat "What does this file do?"
```

## 🎯 Next Steps

1. **Read the [Documentation](DOCS.md)** for detailed usage
2. **Configure keymaps** to your preference
3. **Set up multiple providers** for different use cases
4. **Explore the chat interface** with `:ZekeToggleChat`
5. **Try the diff view** with `:ZekeEdit "improve this code"`

## 🆘 Getting Help

### If Installation Fails

1. **Check Prerequisites**: Ensure Neovim 0.9+ and Rust 2024
2. **Manual Build**: Try building manually
3. **Check Logs**: Look at `:messages` for errors
4. **Clean Install**: Remove and reinstall the plugin

### Support Channels

- **GitHub Issues**: [Report bugs](https://github.com/ghostkellz/zeke.nvim/issues)
- **Discussions**: [Ask questions](https://github.com/ghostkellz/zeke.nvim/discussions)
- **Discord**: [Join community](https://discord.gg/zeke)

### Debug Information

When reporting issues, include:

```lua
-- Run this and include output
:lua print(vim.version())
:lua print(jit.version)
:lua print(vim.fn.has('nvim-0.9'))
```

```bash
# Also include
rustc --version
cargo --version
uname -a  # Linux/macOS
```

---

**Happy coding with Zeke! 🚀**