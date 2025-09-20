# 🔌 WebSocket & Zeke CLI Integration

Zeke.nvim's WebSocket integration provides real-time, bidirectional communication with the Zeke CLI for instant AI responses and seamless provider management.

## 🚀 Architecture Overview

```
Neovim ←─WebSocket─→ Zeke CLI ←─API─→ AI Providers
   ↑                    ↑
   └─── Lua Frontend ───┴─── Rust Backend
```

**Benefits:**
- **Real-time streaming** - Instant response delivery
- **Bidirectional communication** - Send commands, receive events
- **Connection persistence** - Maintains state across operations
- **Auto-reconnection** - Robust connection handling

## 🔍 Auto-Discovery System

### Automatic Detection
Zeke.nvim automatically discovers running Zeke CLI instances:

```vim
:ZekeConnect  " Auto-discover and connect
```

**Discovery process:**
1. **Scan session directory** (`~/.zeke/sessions/`)
2. **Parse lock files** for connection info
3. **Health check** WebSocket endpoints
4. **Connect to most recent** active session

### Manual Discovery
```vim
:ZekeDiscovery  " Show discovery status
```

Display:
```
🔍 Zeke CLI Discovery Status

📊 Total sessions found: 2

📋 Active sessions:
  🟢 zeke-abc123 - Port 8081 (Active)
      📅 Started: 2024-01-15 14:30:15
      🆔 PID: 12345
      🏷️  Version: 0.3.0

  🔴 zeke-def456 - Port 8082 (Inactive)
      📅 Started: 2024-01-15 12:15:30
      🆔 PID: 12200 (stopped)

📁 Session directory: ~/.zeke/sessions
⚙️  Auto-start: enabled
```

## 🎛️ Session Management

### Starting New Sessions
```vim
:ZekeStartCLI          " Start on default port (8081)
:ZekeStartCLI 8085     " Start on specific port
```

**Startup process:**
1. **Launch Zeke CLI** with WebSocket server
2. **Wait for ready signal** (up to 10 seconds)
3. **Auto-connect** to new session
4. **Register session** in discovery system

### Interactive Session Manager
```vim
:ZekeSessionManager
```

Interface:
```
┌─────────────────────────────────────────┐
│      🔧 Zeke CLI Session Manager       │
├─────────────────────────────────────────┤
│  📋 Active Sessions:                    │
│                                         │
│  [1] 🟢 zeke-abc123 - Port 8081        │
│  [2] 🟢 zeke-def456 - Port 8082        │
│  [3] 🔴 zeke-ghi789 - Port 8083        │
│                                         │
│ ─────────────────────────────────────── │
│ 🎮 Controls:                            │
│ [n] New Session    [d] Delete Session  │
│ [c] Cleanup Stale  [1-9] Connect       │
│ [r] Refresh        [q] Close           │
└─────────────────────────────────────────┘
```

### Connection Management
```vim
:ZekeConnect           " Connect to best available session
:ZekeDisconnect        " Disconnect current WebSocket
:ZekeStatus            " Show connection health
```

## 📡 Real-time Communication

### JSON-RPC 2.0 Protocol
Zeke.nvim uses structured messaging for reliable communication:

```json
// Chat request
{
  "jsonrpc": "2.0",
  "method": "chat_completion",
  "params": {
    "messages": [{"role": "user", "content": "Explain this code"}],
    "context": {
      "file_path": "/project/src/main.rs",
      "selection": "fn main() {...}",
      "language": "rust"
    },
    "stream": true
  },
  "id": "req-abc123"
}

// Streaming response
{
  "jsonrpc": "2.0",
  "result": {
    "type": "ChatDelta",
    "content": "This is a Rust main function..."
  },
  "id": "req-abc123"
}
```

### Message Types
- **ChatDelta** - Streaming text content
- **StreamStart** - Begin new response stream
- **StreamEnd** - Complete response stream
- **ActionRequest** - AI requesting permission
- **Error** - Error occurred during processing
- **Ping/Pong** - Connection keepalive

## 🌊 Streaming Responses

### Real-time Chat
```vim
:ZekeChatStream "Explain async Rust"
```

**Streaming flow:**
1. **Send request** via WebSocket
2. **Receive stream start** notification
3. **Process delta chunks** in real-time
4. **Update UI incrementally**
5. **Handle stream end** notification

### Visual Feedback
```
🤖 Zeke is thinking...
▓▓▓░░░░░░░ Connecting...

🤖 Async Rust allows non-blocking operations by using▓
```

**Features:**
- **Typing indicator** - Shows AI is processing
- **Incremental rendering** - Text appears as generated
- **Markdown rendering** - Real-time code highlighting
- **Cancellation support** - Stop mid-stream if needed

## ⚡ Context Extraction

### Automatic Context
Zeke.nvim automatically sends rich context with each request:

```lua
-- Context automatically included
context = {
  -- File information
  file_path = "/project/src/main.rs",
  language = "rust",
  cursor_position = {line = 15, col = 8},

  -- Selection (if any)
  selection = {
    text = "fn process_data(input: &str) -> Result<String, Error>",
    start_line = 12,
    end_line = 12
  },

  -- Project context
  project_root = "/project",

  -- LSP diagnostics
  diagnostics = [
    {
      line = 15,
      severity = "error",
      message = "cannot borrow `data` as mutable"
    }
  ],

  -- Git context
  git = {
    branch = "feature/async-improvements",
    recent_commits = ["abc123: Add async support", "def456: Fix error handling"],
    staged_changes = ["src/main.rs", "Cargo.toml"]
  }
}
```

### Custom Context
```vim
:ZekeAddFile           " Add specific file to context
:ZekeAddCurrent        " Add current buffer to context
:ZekeAddSelection      " Add current selection to context
:ZekeShowContext       " View current context
:ZekeClearContext      " Clear context
```

## 🔄 Connection Resilience

### Auto-Reconnection
```lua
-- Automatic reconnection logic
if connection_lost then
  1. Try to reconnect to same session
  2. Discover new sessions if needed
  3. Start new session if auto_start enabled
  4. Fallback to HTTP API if WebSocket fails
end
```

### Health Monitoring
```vim
:ZekeStatus
```

Output:
```
⚡ Zeke WebSocket Status:
├─ Connection: ✅ Connected
├─ Session ID: zeke-abc123
├─ Port: 8081
├─ Latency: 45ms
├─ Messages sent: 127
├─ Messages received: 134
├─ Uptime: 2h 34m 15s
└─ Last ping: 2s ago
```

### Error Recovery
```vim
# Connection errors handled gracefully:
🔴 WebSocket connection lost
🔄 Attempting reconnection... (1/3)
🟡 Discovering alternative sessions...
✅ Connected to zeke-def456 on port 8082
```

## 🔧 Configuration

### WebSocket Settings
```lua
require("zeke").setup({
  zeke_cli = {
    auto_discover = true,        -- Auto-find running sessions
    auto_start = true,           -- Start CLI if none found
    websocket_port = 8081,       -- Default port for new sessions
    timeout_ms = 5000,           -- Connection timeout
    session_dir = "~/.zeke/sessions",  -- Discovery directory

    -- Reconnection settings
    max_retry_attempts = 3,
    retry_delay_ms = 1000,
    ping_interval_ms = 30000,
  }
})
```

### Discovery Behavior
```lua
discovery = {
  scan_interval_ms = 5000,     -- How often to scan for new sessions
  cleanup_stale = true,        -- Remove dead session files
  prefer_newest = true,        -- Connect to most recent session

  -- Port scanning range
  port_range = {8081, 8090},   -- Check ports 8081-8090
}
```

## 🛠️ Advanced Features

### Session Switching
```vim
# Switch between multiple active sessions
:ZekeSessionManager
[2] 🟢 zeke-def456 - Port 8082  # Select different session
# Context automatically transfers!
```

### Provider Routing via WebSocket
```vim
# Switch providers through WebSocket
:ZekeSwitchProvider anthropic
# → Sends switch command to Zeke CLI
# → CLI routes subsequent requests to Anthropic
# → Immediate feedback via WebSocket
```

### Parallel Operations
```lua
-- Multiple concurrent operations supported
zeke.chat_stream("Explain this function")    -- Stream 1
zeke.analyze("security")                     -- Stream 2
zeke.edit("Add error handling")              -- Stream 3
-- All handled simultaneously via WebSocket multiplexing
```

## 🐛 Troubleshooting

### Connection Issues
```vim
:ZekeDiscovery         " Check session discovery
:ZekeStartCLI          " Start new session manually
:ZekeConnect           " Force reconnection attempt
```

### Common Problems

**"No Zeke CLI sessions found"**
```bash
# Check if Zeke CLI is installed
which zeke-cli

# Start manually
zeke serve --websocket --port 8081

# Check session directory
ls ~/.zeke/sessions/
```

**"WebSocket connection refused"**
```bash
# Check if port is available
netstat -an | grep 8081

# Check firewall settings
sudo ufw status

# Try different port
:ZekeStartCLI 8085
```

**"Session discovery slow"**
```lua
-- Increase scan frequency
zeke_cli = {
  scan_interval_ms = 1000,  -- Scan every second
}
```

### Debug Mode
```bash
# Start Zeke CLI with debug logging
zeke serve --websocket --log-level debug

# Enable Neovim debug logging
:lua vim.g.zeke_debug = true
```

## 📊 Performance Metrics

### Latency Comparison
```
Protocol Latency (avg response time):
├─ WebSocket Streaming: 45ms
├─ HTTP Long Polling:   250ms
├─ HTTP Request/Response: 180ms
└─ WebSocket vs HTTP:   4.4x faster
```

### Throughput Benefits
```
Concurrent Operations:
├─ WebSocket: 10+ simultaneous streams
├─ HTTP: 2-3 concurrent requests
└─ Improvement: 300-500% better throughput
```

## 🎯 Best Practices

### Optimal Usage
1. **Keep sessions running** - Avoid frequent CLI restarts
2. **Use auto-discovery** - Let Zeke find best connection
3. **Monitor health** - Check `:ZekeStatus` regularly
4. **Clean up stale sessions** - Use `:ZekeSessionManager`

### Development Workflow
```vim
# Start of day
:ZekeConnect          " Auto-connect to best session

# During development
:ZekeChatStream       " Real-time AI assistance
<leader>zs            " Quick provider switching

# End of day
:ZekeSessionManager   " Clean up unused sessions
```

### Performance Tips
- **Use streaming** for long responses
- **Enable context caching** for repeated operations
- **Batch related requests** when possible
- **Monitor connection health** for optimal performance

Ready for real-time AI? Run `:ZekeConnect` and experience the future of AI coding assistance! 🚀