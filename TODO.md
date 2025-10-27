# zeke.nvim Overhaul TODO - Claude Code Alternative

## 🎯 Mission: Leverage New Zeke v0.3.0 Backend

The Zeke CLI (v0.3.0) is now production-ready with:
- ✅ 7 AI providers (OpenAI, Claude, xAI, Google, Azure, Ollama, GitHub Copilot)
- ✅ TOML configuration system (zontom)
- ✅ Clean architecture (removed omen, ghostllm)
- ✅ Provider switching and health checks
- ✅ Streaming support
- ✅ File operations

**Goal**: Transform zeke.nvim into a **Claude Code alternative** that seamlessly integrates with the new CLI backend.

---

## 🔥 Critical Issues to Fix

### 1. **Architecture Mismatch** 🚨 P0
**Problem**: Plugin expects WebSocket server, but Zeke v0.3.0 uses CLI commands
**Current**: Plugin tries to connect to `http://localhost:7878` (old HTTP API)
**New Reality**: Zeke is a CLI tool, not a server

**Solution Options**:
- **Option A (Recommended)**: Direct CLI integration via `vim.fn.system()`
  ```lua
  -- Instead of HTTP:
  local response = http_client.post("/api/chat", { message = "..." })

  -- Use CLI directly:
  local output = vim.fn.system('zeke chat "' .. message .. '"')
  ```

- **Option B**: Add HTTP server mode to Zeke CLI (`zeke serve`)
  - Keep existing HTTP client code
  - Start server automatically in background
  - More complex but matches current plugin architecture

**Recommendation**: Go with **Option A** for simplicity and reliability.

---

### 2. **Provider Management** 🔄 P0
**Current**: Hardcoded provider switching via HTTP API
**New**: Use Zeke's provider system

**Changes Needed**:
```lua
-- OLD (lua/zeke/commands.lua)
function M.set_provider(provider)
  http_client.post("/api/provider/switch", { provider = provider })
end

-- NEW
function M.set_provider(provider)
  vim.fn.system('zeke provider switch ' .. provider)
  -- Or read from zeke.toml config
end

-- List providers
function M.list_providers()
  local output = vim.fn.system('zeke provider list')
  return parse_provider_list(output)
end
```

---

### 3. **Configuration Integration** 📝 P0
**Current**: Plugin has its own config in `lua/zeke/config.lua`
**New**: Should read from `~/.config/zeke/zeke.toml`

**Integration Plan**:
```lua
-- lua/zeke/config.lua
local M = {}

function M.load_from_zeke_toml()
  local toml_path = vim.fn.expand("~/.config/zeke/zeke.toml")

  -- Option 1: Parse TOML in Lua (add dependency)
  -- Option 2: Use Zeke CLI to dump config as JSON
  local json_config = vim.fn.system('zeke config dump --json')
  return vim.json.decode(json_config)
end

-- Merge Zeke config with nvim-specific settings
function M.setup(user_opts)
  local zeke_config = M.load_from_zeke_toml()

  M.config = vim.tbl_deep_extend("force", {
    -- Zeke CLI settings
    default_provider = zeke_config.default.provider,
    default_model = zeke_config.default.model,
    providers = zeke_config.providers,

    -- Nvim-specific settings
    keymaps = user_opts.keymaps or {},
    ui = user_opts.ui or {},
    selection = user_opts.selection or {},
  }, user_opts or {})
end
```

**TODO**: Add `zeke config dump --json` command to CLI

---

### 4. **Remove HTTP Client Dependency** 🗑️ P1
**Current**: Uses custom HTTP client (`lua/zeke/http_client.lua`)
**New**: Replace with direct CLI calls

**Files to Update**:
- `lua/zeke/http_client.lua` → Delete or simplify to CLI wrapper
- `lua/zeke/commands.lua` → Replace all HTTP calls with `vim.fn.system()`
- `lua/zeke/init.lua` → Remove HTTP client initialization

---

## 🚀 High-Priority Features (Claude Code Parity)

### 5. **Inline Code Completion** 💡 P0
**Status**: Missing entirely
**Goal**: Ghost text suggestions like GitHub Copilot

**Implementation**:
```lua
-- lua/zeke/completion.lua (NEW FILE)
local M = {}

function M.setup()
  -- Register completion source for nvim-cmp
  require('cmp').register_source('zeke', require('zeke.cmp_source'))
end

function M.get_completion(context)
  local code_before = get_code_before_cursor()
  local code_after = get_code_after_cursor()

  -- Call Zeke CLI with context
  local prompt = string.format(
    "Complete this code:\n```%s\n%s<CURSOR>%s\n```",
    vim.bo.filetype,
    code_before,
    code_after
  )

  local output = vim.fn.system('zeke generate "' .. prompt .. '"')
  return parse_completion(output)
end

-- Show inline ghost text
function M.show_inline_suggestion(suggestion)
  -- Use virtual text to show suggestion
  vim.api.nvim_buf_set_extmark(0, M.ns_id, line, col, {
    virt_text = {{ suggestion, "Comment" }},
    virt_text_pos = "inline",
  })
end
```

**Integration with nvim-cmp**:
```lua
require('cmp').setup({
  sources = {
    { name = 'zeke', priority = 1000 },
    { name = 'nvim_lsp' },
    { name = 'buffer' },
  }
})
```

---

### 6. **Chat Interface Overhaul** 💬 P0
**Current**: Basic floating window
**Goal**: Claude Code-style split pane with history

**Improvements Needed**:
```lua
-- lua/zeke/chat.lua (MAJOR REFACTOR)
local M = {}

M.config = {
  position = "right",  -- right, left, bottom, float
  width = 50,          -- percentage or absolute
  height = 100,
  show_model = true,
  show_tokens = true,
  markdown_rendering = true,
}

function M.open()
  -- Create split window
  local win = create_split_window(M.config)

  -- Render chat UI with:
  -- - Message history
  -- - Token counter
  -- - Model selector dropdown
  -- - Input area at bottom

  setup_chat_keymaps(win)
end

function M.send_message(message)
  -- Stream response from Zeke CLI
  local job_id = vim.fn.jobstart(
    {'zeke', 'stream', 'chat', message},
    {
      on_stdout = function(_, data)
        append_streaming_response(data)
      end,
      on_exit = function()
        mark_message_complete()
      end,
    }
  )
end

function M.render_markdown(text)
  -- Use treesitter for syntax highlighting
  -- Render code blocks with proper highlighting
end
```

---

### 7. **Context Management (@ Mentions)** 📎 P0
**Current**: Basic file context
**Goal**: Claude Code-style @ mentions

**Implementation**:
```lua
-- lua/zeke/context.lua (MAJOR REFACTOR)
local M = {}

M.context_types = {
  buffer = "@buffer",     -- Current buffer
  file = "@file:path",    -- Specific file
  selection = "@sel",     -- Visual selection
  diagnostics = "@diag",  -- LSP diagnostics
  git = "@git:diff",      -- Git changes
  web = "@web:url",       -- Web content
}

function M.parse_at_mentions(message)
  -- Extract @mentions from chat message
  -- Example: "Fix the error in @buffer and @file:api.ts"

  local mentions = {}
  for mention in message:gmatch("@%w+[:%w/%.%-]*") do
    table.insert(mentions, M.resolve_mention(mention))
  end

  return mentions
end

function M.resolve_mention(mention)
  if mention == "@buffer" then
    return {
      type = "buffer",
      content = get_current_buffer_content(),
      metadata = { path = vim.fn.expand("%:p") }
    }
  elseif mention:match("@file:") then
    local path = mention:gsub("@file:", "")
    return {
      type = "file",
      content = read_file(path),
      metadata = { path = path }
    }
  elseif mention == "@diag" then
    return {
      type = "diagnostics",
      content = format_diagnostics(vim.diagnostic.get(0)),
    }
  end
  -- ... more types
end

-- Build full prompt with context
function M.build_prompt(message, contexts)
  local prompt = "You are an AI coding assistant.\n\n"

  for _, ctx in ipairs(contexts) do
    prompt = prompt .. string.format(
      "Context (%s):\n```\n%s\n```\n\n",
      ctx.type,
      ctx.content
    )
  end

  prompt = prompt .. "User: " .. message
  return prompt
end
```

**Chat Integration**:
```lua
-- In chat.lua
function M.send_message(message)
  local contexts = require('zeke.context').parse_at_mentions(message)
  local prompt = require('zeke.context').build_prompt(message, contexts)

  -- Send to Zeke with full context
  local output = vim.fn.system('zeke chat "' .. escape(prompt) .. '"')
end
```

---

### 8. **Code Actions Menu** ⚡ P0
**Current**: Separate commands for each action
**Goal**: Unified code actions menu (like Claude Code)

**Implementation**:
```lua
-- lua/zeke/actions.lua (NEW FILE)
local M = {}

M.actions = {
  { label = "💬 Explain Code", cmd = "explain" },
  { label = "🔧 Fix Issue", cmd = "fix" },
  { label = "✨ Optimize", cmd = "optimize" },
  { label = "🧪 Generate Tests", cmd = "test" },
  { label = "📝 Add Documentation", cmd = "document" },
  { label = "♻️  Refactor", cmd = "refactor" },
  { label = "🔍 Find Bugs", cmd = "audit" },
  { label = "🎨 Format Code", cmd = "format" },
}

function M.show_menu()
  -- Use vim.ui.select for native menu
  vim.ui.select(M.actions, {
    prompt = "Zeke Code Actions",
    format_item = function(item) return item.label end,
  }, function(choice)
    if choice then
      M.execute_action(choice.cmd)
    end
  end)
end

function M.execute_action(action)
  local selection = get_visual_selection()
  local filetype = vim.bo.filetype

  local prompts = {
    explain = "Explain this code:",
    fix = "Fix any issues in this code:",
    optimize = "Optimize this code for performance:",
    test = "Generate unit tests for this code:",
    document = "Add documentation comments to this code:",
    refactor = "Refactor this code to improve readability:",
    audit = "Find potential bugs and security issues:",
    format = "Format this code according to best practices:",
  }

  local prompt = string.format(
    "%s\n```%s\n%s\n```",
    prompts[action],
    filetype,
    selection
  )

  local output = vim.fn.system('zeke chat "' .. escape(prompt) .. '"')
  show_result(output)
end
```

**Keymap**:
```lua
vim.keymap.set({ 'n', 'v' }, '<leader>za', '<cmd>lua require("zeke.actions").show_menu()<CR>',
  { desc = "Zeke Code Actions" })
```

---

### 9. **Diff Improvements** 📊 P1
**Current**: Basic diff accept/reject
**Goal**: Enhanced navigation and partial acceptance

**Improvements**:
```lua
-- lua/zeke/diff.lua (ENHANCE)

-- Add partial diff acceptance
function M.accept_hunk()
  -- Accept only the current hunk
  local hunk = get_current_hunk()
  apply_hunk(hunk)
  goto_next_hunk()
end

-- Keyboard navigation
function M.setup_diff_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true }

  vim.keymap.set('n', ']c', goto_next_change, opts)
  vim.keymap.set('n', '[c', goto_prev_change, opts)
  vim.keymap.set('n', '<leader>dh', M.accept_hunk, opts)
  vim.keymap.set('n', '<leader>da', M.accept_all, opts)
  vim.keymap.set('n', '<leader>dr', M.reject_all, opts)
  vim.keymap.set('n', '<leader>dd', M.toggle_diff_view, opts)
end

-- Show diff stats
function M.show_stats()
  local stats = calculate_diff_stats()
  notify(string.format(
    "Changes: +%d -%d (~%d lines)",
    stats.additions,
    stats.deletions,
    stats.total
  ))
end
```

---

### 10. **Streaming Support** 🌊 P1
**Current**: Waits for full response
**Goal**: Real-time streaming like Claude Code

**Implementation**:
```lua
-- lua/zeke/stream.lua (NEW FILE)
local M = {}

function M.stream_chat(message, on_chunk, on_complete)
  -- Use jobstart with streaming
  local chunks = {}

  local job_id = vim.fn.jobstart(
    {'zeke', 'stream', 'chat', message},
    {
      on_stdout = function(_, data)
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(chunks, line)
            on_chunk(line)  -- Update UI immediately
          end
        end
      end,
      on_exit = function(_, exit_code)
        local full_response = table.concat(chunks, "\n")
        on_complete(full_response, exit_code)
      end,
    }
  )

  return job_id  -- Return for cancellation
end

function M.cancel_stream(job_id)
  vim.fn.jobstop(job_id)
end
```

**Chat Integration**:
```lua
-- In chat.lua
function M.send_message_streaming(message)
  append_user_message(message)

  local response_bufnr, response_line = create_ai_message_placeholder()

  M.current_job = require('zeke.stream').stream_chat(
    message,
    function(chunk)
      -- Append chunk to buffer in real-time
      append_to_message(response_bufnr, response_line, chunk)
    end,
    function(full_response, exit_code)
      if exit_code == 0 then
        mark_message_complete(response_bufnr)
      else
        show_error("Stream failed")
      end
    end
  )
end

-- ESC to cancel
vim.keymap.set('n', '<Esc>', function()
  if M.current_job then
    require('zeke.stream').cancel_stream(M.current_job)
    show_notification("Cancelled")
  end
end, { buffer = chat_bufnr })
```

---

## 🎨 Nice-to-Have Features

### 11. **Provider Fallback** 🔄 P2
**Goal**: Auto-switch on provider failure

```lua
-- Read from zeke.toml
local fallback_order = config.nvim.provider_fallback
-- ["copilot", "ollama", "google", "claude", "openai", "xai"]

function M.chat_with_fallback(message)
  for _, provider in ipairs(fallback_order) do
    local ok, result = pcall(zeke_chat, message, provider)
    if ok then
      return result
    end
    -- Try next provider on failure
  end
  error("All providers failed")
end
```

---

### 12. **Model Selector UI** 🎯 P2
**Goal**: Quick model switching with visual feedback

```lua
function M.show_model_picker()
  local models = get_available_models()

  vim.ui.select(models, {
    prompt = "Select Model",
    format_item = function(model)
      return string.format(
        "%s %s (%s)",
        model.icon,
        model.name,
        model.provider
      )
    end,
  }, function(choice)
    if choice then
      set_active_model(choice)
    end
  end)
end
```

---

### 13. **Statusline Integration** 📊 P2
**Goal**: Show active model and token usage

```lua
-- lua/zeke/statusline.lua (NEW FILE)
function M.get_status()
  local model = get_current_model()
  local tokens = get_token_usage()  -- From last request

  return string.format(
    "🤖 %s • %dk/%dk",
    model,
    math.floor(tokens.used / 1000),
    math.floor(tokens.limit / 1000)
  )
end

-- lualine integration
require('lualine').setup({
  sections = {
    lualine_x = { 'zeke#status' }
  }
})
```

---

### 14. **Git Integration** 🔀 P3
**Goal**: Send git diff/commit context to AI

```lua
function M.explain_commit(commit_sha)
  local diff = vim.fn.system('git show ' .. commit_sha)
  local message = string.format(
    "Explain this commit:\n```diff\n%s\n```",
    diff
  )
  zeke_chat(message)
end

function M.suggest_commit_message()
  local diff = vim.fn.system('git diff --staged')
  local message = "Generate a concise commit message for:\n```diff\n" .. diff .. "\n```"
  local suggestion = zeke_chat(message)
  vim.fn.setreg('+', suggestion)  -- Copy to clipboard
  notify("Commit message copied to clipboard")
end
```

---

## 📋 Implementation Roadmap

### Phase 1: Core Overhaul (Week 1-2) 🔥
**Goal**: Make plugin work with new Zeke v0.3.0

- [ ] **Replace HTTP client with CLI calls** (P0)
  - Update `lua/zeke/commands.lua`
  - Replace all `http_client.*` calls with `vim.fn.system()`
  - Test basic commands work

- [ ] **Configuration integration** (P0)
  - Read from `~/.config/zeke/zeke.toml`
  - Add `zeke config dump --json` to CLI
  - Merge Zeke + nvim configs

- [ ] **Provider management** (P0)
  - Use `zeke provider list/switch`
  - Remove hardcoded provider logic

- [ ] **Update documentation** (P0)
  - Remove references to old HTTP API
  - Document new CLI-based architecture

### Phase 2: Claude Code Parity (Week 3-4) 💎
**Goal**: Match core Claude Code features

- [ ] **Inline completions** (P0)
  - Implement ghost text suggestions
  - nvim-cmp integration
  - Trigger on typing

- [ ] **Chat UI overhaul** (P0)
  - Split pane interface
  - Message history with scrollback
  - Markdown rendering
  - Model/token display

- [ ] **@ mentions context** (P0)
  - Parse @buffer, @file:path, @sel, @diag
  - Build context-aware prompts
  - Show context chips in chat

- [ ] **Code actions menu** (P0)
  - Unified actions menu
  - Visual selection support
  - Quick keybindings

- [ ] **Streaming responses** (P1)
  - Real-time token streaming
  - Cancelable requests (ESC)
  - Progress indicators

### Phase 3: Polish & Extras (Week 5-6) ✨
**Goal**: Production-ready plugin

- [ ] **Enhanced diff management** (P1)
  - Partial hunk acceptance
  - Better navigation (]c, [c)
  - Diff statistics

- [ ] **Provider fallback** (P2)
  - Auto-retry on failure
  - Respect zeke.toml fallback order

- [ ] **Model selector UI** (P2)
  - Visual model picker
  - Show model capabilities

- [ ] **Statusline integration** (P2)
  - Active model display
  - Token usage counter

- [ ] **Git integration** (P3)
  - Explain commits
  - Generate commit messages
  - Review diffs with AI

---

## 🧪 Testing Checklist

### Basic Functionality
- [ ] `:ZekeChat "hello"` works
- [ ] `:ZekeExplain` on current buffer
- [ ] `:ZekeEdit "add error handling"` shows diff
- [ ] Provider switching: `:ZekeSetProvider ollama`
- [ ] Model switching: `:ZekeSetModel gpt-4`

### Configuration
- [ ] Reads `~/.config/zeke/zeke.toml`
- [ ] Respects default provider
- [ ] Respects default model
- [ ] nvim-specific config overrides work

### UI/UX
- [ ] Chat window opens correctly
- [ ] Streaming updates in real-time
- [ ] @ mentions work in chat
- [ ] Code actions menu appears
- [ ] Inline completions show up

### Edge Cases
- [ ] Handles provider failures gracefully
- [ ] Cancels requests on ESC
- [ ] Validates @ mention paths exist
- [ ] Shows errors when Zeke CLI not found
- [ ] Works without internet (Ollama only)

---

## 📚 Documentation Updates Needed

### README.md
- [ ] Update architecture diagram (CLI not HTTP API)
- [ ] Remove WebSocket references
- [ ] Add zeke.toml configuration section
- [ ] Document new @ mention syntax
- [ ] Update installation (no zig build needed)

### example-config.lua
- [ ] Remove http_api section
- [ ] Add cli_path option
- [ ] Document provider_fallback
- [ ] Show @ mention examples

### New Docs
- [ ] `MIGRATION.md` - Guide for v0.2 → v0.3 users
- [ ] `CONFIGURATION.md` - Deep dive on config system
- [ ] `CONTEXT.md` - @ mention reference
- [ ] `KEYMAPS.md` - All keyboard shortcuts

---

## 🎯 Success Criteria

**The plugin will be considered "complete" when**:

1. ✅ Works seamlessly with Zeke v0.3.0 CLI (no HTTP API needed)
2. ✅ Provides inline completions like Copilot
3. ✅ Has a polished chat UI with streaming
4. ✅ Supports @ mentions for context
5. ✅ Handles all 7 providers with fallback
6. ✅ Has comprehensive documentation
7. ✅ Passes all test cases

**Comparison to Claude Code**:
- [x] Multi-provider support (even better - 7 providers!)
- [ ] Inline ghost text completions
- [x] Chat interface with history
- [ ] @ mention context system
- [x] Code actions menu
- [x] Diff preview and management
- [ ] Real-time streaming

---

## 🚀 Quick Start for Contributors

```bash
# 1. Ensure Zeke CLI is installed
cd /data/projects/zeke
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/zeke /usr/local/bin/

# 2. Configure Zeke
cp zeke.toml.example ~/.config/zeke/zeke.toml
# Edit with your API keys and preferences

# 3. Test Zeke CLI
zeke provider list
zeke chat "hello world"

# 4. Install plugin
cd /data/projects/zeke.nvim
# Use your plugin manager (lazy.nvim, packer, etc.)

# 5. Run tests
nvim --headless -c "lua require('plenary.test_harness').test_directory('tests')"
```

---

## 🎉 Conclusion

This is an ambitious overhaul, but the payoff is huge:
- **Simpler architecture** (CLI vs HTTP server)
- **Better integration** (reads zeke.toml directly)
- **More features** (7 providers, @ mentions, streaming)
- **True Claude Code alternative** for Neovim users

Let's build this! 🚀
