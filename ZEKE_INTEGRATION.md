# ZEKE.nvim Plugin Integration Guide

This document explains how to integrate ZEKE with a Neovim plugin by using the ZEKE Rust crate as a dependency or calling the ZEKE CLI/API.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   zeke.nvim     │    │      ZEKE       │    │  AI Providers   │
│  (Lua Plugin)   │◄──►│   (Rust Crate)  │◄──►│ OpenAI, Claude, │
│                 │    │                 │    │ Copilot, etc.   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Integration Options

There are three main ways to integrate ZEKE with your Neovim plugin:

### 1. HTTP API Integration (Recommended)

The easiest approach is to use ZEKE's built-in HTTP API server:

```lua
-- Start ZEKE API server
vim.fn.jobstart({'zeke', 'server', '--host', '127.0.0.1', '--port', '7777'})

-- Make HTTP requests to ZEKE
local function chat_with_ai(message)
    local curl = require('plenary.curl')
    local response = curl.post('http://127.0.0.1:7777/api/v1/chat', {
        headers = {
            ['Content-Type'] = 'application/json',
        },
        body = vim.json.encode({
            message = message,
            model = 'gpt-4',
            temperature = 0.7
        })
    })

    local result = vim.json.decode(response.body)
    return result.data.content
end
```

### 2. CLI Integration

Call ZEKE commands directly via the CLI:

```lua
local function explain_code(code, language)
    local cmd = {'zeke', 'explain', code}
    if language then
        table.insert(cmd, '--language')
        table.insert(cmd, language)
    end

    local result = vim.fn.system(cmd)
    return result
end

local function chat_with_ai(message)
    local result = vim.fn.system({'zeke', 'chat', message})
    return result
end
```

### 3. Rust Crate Integration (Advanced)

For advanced use cases, you can create a Lua module with Rust bindings:

#### Add ZEKE to your Cargo.toml

```toml
[dependencies]
zeke = { git = "https://github.com/ghostkellz/zeke", branch = "main" }
tokio = { version = "1.0", features = ["full"] }
mlua = "0.9"
```

#### Create Rust bindings

```rust
use mlua::prelude::*;
use zeke::{ProviderManager, ChatRequest, ChatMessage};

fn chat_completion(lua: &Lua, message: String) -> LuaResult<String> {
    let rt = tokio::runtime::Runtime::new().unwrap();

    rt.block_on(async {
        let manager = ProviderManager::new();

        let request = ChatRequest {
            messages: vec![ChatMessage {
                role: "user".to_string(),
                content: message,
            }],
            model: Some("gpt-4".to_string()),
            temperature: Some(0.7),
            max_tokens: Some(2048),
            stream: Some(false),
        };

        match manager.chat_completion(&request).await {
            Ok(response) => Ok(response.content),
            Err(e) => Err(LuaError::RuntimeError(e.to_string())),
        }
    })
}

#[mlua::lua_module]
fn zeke_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    exports.set("chat", lua.create_function(chat_completion)?)?;
    Ok(exports)
}
```

## Available Endpoints

### HTTP API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Server health check |
| `/api/v1/chat` | POST | Chat with AI |
| `/api/v1/chat/stream` | POST | Streaming chat |
| `/api/v1/code/explain` | POST | Explain code |
| `/api/v1/code/edit` | POST | Edit code with AI |
| `/api/v1/providers` | GET | List available providers |
| `/api/v1/providers/switch` | POST | Switch AI provider |
| `/v1/messages` | POST | Claude API compatible |

### CLI Commands

| Command | Description | Example |
|---------|-------------|---------|
| `zeke chat <message>` | Chat with AI | `zeke chat "Explain async/await"` |
| `zeke explain <code>` | Explain code | `zeke explain "fn main() {}"` |
| `zeke provider list` | List providers | `zeke provider list` |
| `zeke provider switch <name>` | Switch provider | `zeke provider switch claude` |
| `zeke server` | Start API server | `zeke server --port 7777` |

## Configuration

### ZEKE Configuration

ZEKE looks for configuration in:
- `~/.config/zeke/config.toml`
- `./zeke.toml`
- Environment variables

Example configuration:

```toml
[providers.openai]
api_key = "sk-..."
model = "gpt-4"

[providers.claude]
api_key = "..."
model = "claude-3-5-sonnet-20241022"

[providers.copilot]
# Uses GitHub authentication

[server]
host = "127.0.0.1"
port = 7777
```

### Environment Variables

```bash
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="..."
export GITHUB_TOKEN="ghp_..."
```

## Example Neovim Plugin Structure

```
zeke.nvim/
├── lua/
│   └── zeke/
│       ├── init.lua          # Main plugin entry
│       ├── api.lua           # HTTP API client
│       ├── config.lua        # Configuration
│       └── ui.lua            # UI components
├── plugin/
│   └── zeke.lua              # Plugin setup
└── README.md
```

### Basic Plugin Example

```lua
-- lua/zeke/init.lua
local M = {}
local api = require('zeke.api')

function M.setup(opts)
    opts = opts or {}

    -- Start ZEKE server if not running
    if not api.is_server_running() then
        api.start_server(opts.port or 7777)
    end
end

function M.chat(message)
    return api.chat_completion(message)
end

function M.explain_selection()
    local selection = vim.fn.getline("'<", "'>")
    local code = table.concat(selection, "\n")
    local explanation = api.explain_code(code, vim.bo.filetype)

    -- Show explanation in floating window
    vim.api.nvim_echo({{explanation, "Normal"}}, false, {})
end

return M
```

```lua
-- lua/zeke/api.lua
local M = {}
local curl = require('plenary.curl')

local base_url = 'http://127.0.0.1:7777'

function M.is_server_running()
    local response = curl.get(base_url .. '/health', {
        timeout = 1000,
    })
    return response.status == 200
end

function M.start_server(port)
    vim.fn.jobstart({'zeke', 'server', '--port', tostring(port)}, {
        detach = true,
    })

    -- Wait for server to start
    vim.wait(3000, function()
        return M.is_server_running()
    end)
end

function M.chat_completion(message)
    local response = curl.post(base_url .. '/api/v1/chat', {
        headers = {
            ['Content-Type'] = 'application/json',
        },
        body = vim.json.encode({
            message = message,
        })
    })

    if response.status == 200 then
        local result = vim.json.decode(response.body)
        return result.data.content
    else
        error('Chat request failed: ' .. response.status)
    end
end

function M.explain_code(code, language)
    local response = curl.post(base_url .. '/api/v1/code/explain', {
        headers = {
            ['Content-Type'] = 'application/json',
        },
        body = vim.json.encode({
            code = code,
            language = language,
        })
    })

    if response.status == 200 then
        local result = vim.json.decode(response.body)
        return result.data.explanation
    else
        error('Explain request failed: ' .. response.status)
    end
end

return M
```

## Best Practices

1. **Error Handling**: Always handle API failures gracefully
2. **Server Management**: Check if ZEKE server is running before making requests
3. **Configuration**: Allow users to configure API endpoints and keys
4. **Performance**: Consider caching responses for repeated requests
5. **User Experience**: Provide feedback during long-running operations

## Example Usage in Neovim

```lua
-- In your init.lua or plugin configuration
require('zeke').setup({
    port = 7777,
    auto_start = true,
})

-- Create keymaps
vim.keymap.set('v', '<leader>ae', function()
    require('zeke').explain_selection()
end, { desc = 'Explain selected code' })

vim.keymap.set('n', '<leader>ac', function()
    local message = vim.fn.input('Chat with AI: ')
    if message ~= '' then
        local response = require('zeke').chat(message)
        print(response)
    end
end, { desc = 'Chat with AI' })
```

## Dependencies

Your Neovim plugin will need:

- **plenary.nvim** (for HTTP requests)
- **nvim 0.8+** (for modern Lua APIs)
- **ZEKE binary** available in PATH

## Repository Links

- **ZEKE Core**: https://github.com/ghostkellz/zeke
- **Example Plugin**: https://github.com/ghostkellz/zeke.nvim (your separate repo)

## License

ZEKE is licensed under the MIT License. See the main repository for details.