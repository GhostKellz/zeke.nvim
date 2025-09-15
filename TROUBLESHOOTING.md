# 🔧 Troubleshooting Guide

Common issues and solutions for **zeke.nvim**.

## 📖 Table of Contents

- [🚨 Installation Issues](#-installation-issues)
- [🤖 Provider Issues](#-provider-issues)
- [🔑 API Key Problems](#-api-key-problems)
- [💬 UI and Interface Issues](#-ui-and-interface-issues)
- [📁 Context and Workspace Issues](#-context-and-workspace-issues)
- [⚡ Performance Issues](#-performance-issues)
- [🔍 Debugging](#-debugging)
- [🆘 Getting Help](#-getting-help)

## 🚨 Installation Issues

### "Module 'zeke_nvim' not found"

**Symptoms:**
```
Error: Failed to load zeke_nvim Rust module: module 'zeke_nvim' not found
```

**Causes & Solutions:**

#### 1. Build Failed
```bash
# Check if library exists
cd ~/.local/share/nvim/lazy/zeke.nvim  # or your plugin path
ls target/release/libzeke_nvim.*

# If missing, build manually
cargo clean
cargo build --release

# Verify build succeeded
ls target/release/libzeke_nvim.*
```

#### 2. Wrong Target Architecture (M1 Mac)
```bash
# For M1 Macs, specify target
cargo build --release --target=aarch64-apple-darwin

# Or set as default
rustup default stable-aarch64-apple-darwin
cargo build --release
```

#### 3. Missing Dependencies
```bash
# Linux: Install build tools
sudo apt update
sudo apt install build-essential pkg-config libssl-dev

# macOS: Install Xcode tools
xcode-select --install

# Windows: Install Visual Studio Build Tools
# Download from: https://visualstudio.microsoft.com/visual-cpp-build-tools/
```

#### 4. Permissions Issue
```bash
# Fix permissions
sudo chown -R $USER:$USER ~/.local/share/nvim/
chmod -R 755 ~/.local/share/nvim/
```

### "Rust compiler not found"

**Solution:**
```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Verify installation
rustc --version
cargo --version

# Update if needed
rustup update
```

### Build Hangs or Takes Too Long

**Solutions:**

#### 1. Parallel Build
```bash
# Use parallel jobs
cargo build --release -j 4  # Use 4 cores
```

#### 2. Offline Build (if network issues)
```bash
# Build in offline mode
cargo build --release --offline
```

#### 3. Clean Build
```bash
# Clean and rebuild
cargo clean
rm -rf target/
cargo build --release
```

## 🤖 Provider Issues

### OpenAI Issues

#### "Invalid API key"
```bash
# Check API key format
echo $OPENAI_API_KEY
# Should start with 'sk-' and be ~51 characters

# Test API key directly
curl -H "Authorization: Bearer $OPENAI_API_KEY" \
     https://api.openai.com/v1/models
```

#### "Rate limit exceeded"
```lua
-- Reduce request frequency
require('zeke').setup({
  temperature = 0.3,  -- Lower temperature for faster responses
  max_tokens = 1024,  -- Shorter responses
})
```

#### "Model not found"
```lua
-- Check available models
local models = require('zeke').list_models()
print(vim.inspect(models))

-- Use a standard model
require('zeke').set_model('gpt-3.5-turbo')
```

### Claude Issues

#### "Authentication failed"
```bash
# Check API key
echo $ANTHROPIC_API_KEY
# Should be a long string without 'sk-' prefix

# Test API directly
curl -H "x-api-key: $ANTHROPIC_API_KEY" \
     -H "anthropic-version: 2023-06-01" \
     https://api.anthropic.com/v1/messages
```

#### "Model access denied"
```lua
-- Try a different model
require('zeke').set_model('claude-3-haiku-20240307')  -- Usually available
```

### Ollama Issues

#### "Connection refused"
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Start Ollama if not running
ollama serve

# Check Ollama status
ps aux | grep ollama
```

#### "Model not found"
```bash
# List available models
ollama list

# Pull a model if needed
ollama pull llama2

# Test model
ollama run llama2 "Hello world"
```

#### Custom Ollama Host
```bash
# If running on different host/port
export OLLAMA_HOST="http://192.168.1.100:11434"

# Or in Neovim config
vim.env.OLLAMA_HOST = "http://192.168.1.100:11434"
```

### GitHub Copilot Issues

#### "GitHub token invalid"
```bash
# Re-authenticate with GitHub CLI
gh auth logout
gh auth login

# Get new token
gh auth token

# Verify token
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/user
```

#### "Copilot subscription required"
- Ensure you have an active GitHub Copilot subscription
- Check at: https://github.com/settings/copilot

## 🔑 API Key Problems

### Environment Variables Not Loading

#### 1. Check Shell Profile
```bash
# Add to ~/.bashrc, ~/.zshrc, or ~/.profile
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="..."

# Reload shell
source ~/.bashrc  # or ~/.zshrc
```

#### 2. Neovim Not Inheriting Environment
```bash
# Start Neovim from correct shell
# Avoid GUI launchers that might not load environment

# Or set in Neovim config
vim.env.OPENAI_API_KEY = "sk-..."
```

#### 3. Use .env File
```lua
-- Create ~/.config/zeke/.env
-- OPENAI_API_KEY=sk-...
-- ANTHROPIC_API_KEY=...

-- Load in config
local function load_env()
  local env_file = vim.fn.expand('~/.config/zeke/.env')
  if vim.fn.filereadable(env_file) == 1 then
    for line in io.lines(env_file) do
      local key, value = line:match('([^=]+)=(.+)')
      if key and value then
        vim.env[key] = value
      end
    end
  end
end

load_env()
require('zeke').setup({
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
  },
})
```

### API Key Verification

```lua
-- Add to config to verify keys
vim.api.nvim_create_user_command('ZekeCheckKeys', function()
  local keys = {
    'OPENAI_API_KEY',
    'ANTHROPIC_API_KEY',
    'GITHUB_TOKEN',
  }

  for _, key in ipairs(keys) do
    local value = vim.env[key]
    if value then
      print(key .. ': ' .. value:sub(1, 10) .. '...')
    else
      print(key .. ': NOT SET')
    end
  end
end, {})
```

## 💬 UI and Interface Issues

### Chat Window Not Opening

#### 1. Check for Errors
```lua
-- Add error handling
local ok, err = pcall(require('zeke').toggle_chat)
if not ok then
  print('Error opening chat:', err)
end
```

#### 2. Window Size Issues
```lua
-- Try smaller window
require('zeke').setup({
  ui = {
    chat = {
      width = 0.5,   -- Smaller width
      height = 0.5,  -- Smaller height
    },
  },
})
```

#### 3. Border Issues
```lua
-- Disable border if causing issues
require('zeke').setup({
  ui = {
    chat = {
      border = 'none',
    },
  },
})
```

### Keymaps Not Working

#### 1. Check for Conflicts
```lua
-- List all keymaps
:map <leader>z

-- Check specific keymap
:map <leader>zc
```

#### 2. Disable Conflicting Plugins
```lua
-- Temporarily disable other plugins to test
```

#### 3. Use Different Keys
```lua
require('zeke').setup({
  keymaps = {
    chat = '<F1>',      -- Use function keys
    edit = '<F2>',
    toggle_chat = '<C-g>c',  -- Use Ctrl combinations
  },
})
```

### Floating Window Issues

#### 1. Terminal Size Issues
```lua
-- Check terminal size
print('Columns:', vim.o.columns, 'Lines:', vim.o.lines)

-- Use fixed size if needed
require('zeke').setup({
  ui = {
    chat = {
      width = 80,   -- Fixed width
      height = 24,  -- Fixed height
    },
  },
})
```

#### 2. Z-index Issues
```lua
-- Use different window options
local function custom_window()
  return {
    relative = 'editor',
    width = 80,
    height = 24,
    row = 2,
    col = 2,
    style = 'minimal',
    border = 'single',
    zindex = 1000,  -- High z-index
  }
end
```

## 📁 Context and Workspace Issues

### Workspace Not Detected

#### 1. Manual Workspace Setup
```lua
-- Set workspace manually
require('zeke.workspace').workspace_root = '/path/to/project'
require('zeke.workspace').scan_workspace()
```

#### 2. Add Project Markers
```bash
# Add a marker file
touch .zeke-workspace

# Or use git
git init
```

### Files Not Found in Search

#### 1. Check File Patterns
```lua
require('zeke').setup({
  workspace = {
    include_patterns = {
      '*.lua', '*.rs', '*.py',  -- Add your file types
      '**/src/**/*',           -- Search in src directories
    },
  },
})
```

#### 2. Force Rescan
```lua
-- Manually rescan workspace
require('zeke.workspace').scan_workspace()
```

### Context Too Large

#### 1. Limit File Size
```lua
require('zeke').setup({
  workspace = {
    max_file_size = 524288,  -- 512KB max
  },
})
```

#### 2. Use Selections
```lua
-- Instead of adding whole files, use selections
-- Select code in visual mode, then:
require('zeke').add_selection_to_context()
```

## ⚡ Performance Issues

### Slow Responses

#### 1. Use Faster Models
```lua
-- Switch to faster models
require('zeke').set_provider('ollama')  -- Local, fast
require('zeke').set_model('llama2')

-- Or use smaller OpenAI models
require('zeke').set_model('gpt-3.5-turbo')
```

#### 2. Reduce Context
```lua
-- Clear context regularly
require('zeke').clear_context()

-- Reduce token limit
require('zeke').setup({
  max_tokens = 1024,  -- Shorter responses
})
```

#### 3. Disable Streaming
```lua
require('zeke').setup({
  stream = false,  -- Disable streaming
})
```

### High Memory Usage

#### 1. Limit Workspace Size
```lua
require('zeke').setup({
  workspace = {
    max_files = 1000,        -- Limit file count
    max_file_size = 524288,  -- 512KB per file
  },
})
```

#### 2. Clear Chat History
```lua
-- Clear conversation history periodically
require('zeke.ui').clear_chat()
```

### Neovim Freezing

#### 1. Check for Infinite Loops
```bash
# Monitor CPU usage
top -p $(pgrep nvim)
```

#### 2. Cancel Long Operations
```lua
-- Cancel all tasks
require('zeke').cancel_all_tasks()
```

#### 3. Restart Plugin
```lua
-- Restart Zeke
:lua package.loaded['zeke'] = nil
:lua require('zeke').setup({})
```

## 🔍 Debugging

### Enable Debug Mode

```lua
require('zeke').setup({
  debug = true,
  log_level = 'debug',
})
```

### Check Messages

```vim
:messages  " View Neovim messages
:messages clear  " Clear messages
```

### Lua Debug Information

```lua
-- Add debug prints
vim.api.nvim_create_user_command('ZekeDebug', function()
  print('Zeke Debug Info:')
  print('Neovim version:', vim.version())
  print('Rust available:', vim.fn.executable('rustc'))
  print('Cargo available:', vim.fn.executable('cargo'))

  local ok, zeke_nvim = pcall(require, 'zeke_nvim')
  print('Rust module loaded:', ok)
  if not ok then
    print('Error:', zeke_nvim)
  end

  print('Current provider:', require('zeke').get_current_provider())
  print('Current model:', require('zeke').get_current_model())

  local context = require('zeke').show_context()
  print('Context:', context)
end, {})
```

### Check File Permissions

```bash
# Check plugin directory permissions
ls -la ~/.local/share/nvim/lazy/zeke.nvim/

# Check library permissions
ls -la ~/.local/share/nvim/lazy/zeke.nvim/target/release/libzeke_nvim.*
```

### Network Debugging

```bash
# Test network connectivity
curl -I https://api.openai.com/v1/models
curl -I https://api.anthropic.com/v1/messages

# Check DNS resolution
nslookup api.openai.com
```

### Plugin Conflicts

```lua
-- Minimal config to test for conflicts
-- Put in a separate file and test
require('zeke').setup({
  default_provider = 'ollama',  -- No API key needed
})

-- Test basic functionality
vim.keymap.set('n', '<F1>', function()
  require('zeke').chat('test')
end)
```

## 🆘 Getting Help

### Before Reporting Issues

1. **Update Everything:**
   ```bash
   # Update Rust
   rustup update

   # Update Neovim (if using package manager)
   brew upgrade neovim  # macOS
   # or
   sudo apt update && sudo apt upgrade neovim  # Ubuntu
   ```

2. **Try Minimal Config:**
   - Create a minimal `init.lua` with just Zeke
   - Test if issue persists

3. **Check Dependencies:**
   ```bash
   nvim --version
   rustc --version
   cargo --version
   ```

### Information to Include

When reporting issues, include:

1. **System Information:**
   ```bash
   uname -a  # OS info
   nvim --version
   rustc --version
   ```

2. **Plugin Information:**
   ```lua
   :lua print(vim.inspect(require('zeke').get_status()))
   ```

3. **Error Messages:**
   - Full error text from `:messages`
   - Lua stack traces
   - Build output if build failed

4. **Configuration:**
   - Your `setup()` call
   - Relevant keymaps
   - Other plugins that might conflict

5. **Steps to Reproduce:**
   - Exact commands used
   - Expected vs actual behavior

### Support Channels

1. **GitHub Issues:**
   - Bug reports: [Issues](https://github.com/ghostkellz/zeke.nvim/issues)
   - Feature requests: [Issues](https://github.com/ghostkellz/zeke.nvim/issues)

2. **GitHub Discussions:**
   - Questions: [Discussions](https://github.com/ghostkellz/zeke.nvim/discussions)
   - General help: [Discussions](https://github.com/ghostkellz/zeke.nvim/discussions)

3. **Discord:**
   - Real-time help: [Discord Server](https://discord.gg/zeke)

### Emergency Reset

If everything is broken:

```bash
# 1. Remove plugin
rm -rf ~/.local/share/nvim/lazy/zeke.nvim

# 2. Clear Neovim cache
rm -rf ~/.cache/nvim/

# 3. Reinstall
# Re-add to your plugin config and restart Neovim
```

### Common Solutions Summary

| Problem | Quick Fix |
|---------|-----------|
| Module not found | `cargo build --release` |
| API key errors | Check environment variables |
| UI not opening | Try smaller window size |
| Slow responses | Switch to Ollama or smaller models |
| High memory | Clear context and limit workspace |
| Keymaps not working | Check for conflicts, use different keys |
| Build fails | Install build dependencies |
| Provider errors | Verify API keys and permissions |

---

**Still having issues?** Don't hesitate to reach out on [GitHub](https://github.com/ghostkellz/zeke.nvim/issues) or [Discord](https://discord.gg/zeke)!