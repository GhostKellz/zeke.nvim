# ⚡ Provider & Model Switching

Zeke.nvim's revolutionary switching system lets you seamlessly move between AI providers and models without interrupting your workflow.

## 🎛️ Quick Switcher

### Instant Access
```vim
<leader>zs  " Quick switcher popup
:ZekeSwitcher
```

**Features:**
- **Tab-based interface** - Providers tab and Models tab
- **Real-time status** - See current provider and model
- **Instant switching** - No restart required
- **Keyboard navigation** - Arrow keys, Tab, Enter

### Navigation
```
┌─────────────────────────────────────┐
│          ⚡ Quick Switcher          │
├─────────────────────────────────────┤
│  [🔌 Providers]   🤖 Models        │
│                                     │
│ 📍 Current: openai → gpt-4         │
│                                     │
│ 🔌 Available Providers:             │
│ ▶ ⭐ 🧠 OpenAI (4 models)           │
│      🤖 Anthropic (3 models)       │
│      🏠 Ollama (8 models)           │
│      🐙 GitHub Copilot (1 model)    │
└─────────────────────────────────────┘
```

**Controls:**
- `↑/↓` - Navigate items
- `Tab` - Switch between Provider/Model tabs
- `Enter` - Select item
- `r` - Refresh status
- `q/Esc` - Close

## 🔄 Cycling Commands

### Provider Cycling
```vim
<leader>zp           " Cycle through providers
:ZekeCycleProvider   " Command version
```

**Cycle order:**
1. GhostLLM (intelligent routing)
2. GitHub Copilot (code completion)
3. OpenAI (general purpose)
4. Anthropic (reasoning)
5. Ollama (local/privacy)

### Model Cycling
```vim
<leader>zm         " Cycle through models
:ZekeCycleModel    " Command version
```

**Per-provider models:**
- **OpenAI**: gpt-4 → gpt-4-turbo → gpt-3.5-turbo
- **Anthropic**: claude-3-opus → claude-3-sonnet → claude-3-haiku
- **Ollama**: llama3:8b → deepseek-coder → codellama → mistral
- **GitHub**: copilot (single model)

## 🎯 Direct Switching

### Provider Commands
```vim
:ZekeSwitchProvider       " Open provider selector
:ZekeSetProvider openai   " Switch directly to OpenAI
:ZekeSetProvider anthropic " Switch directly to Anthropic
:ZekeSetProvider ollama   " Switch directly to Ollama
:ZekeSetProvider github   " Switch directly to GitHub Copilot
```

### Model Commands
```vim
:ZekeSwitchModel          " Open model selector
:ZekeSetModel gpt-4       " Switch to GPT-4
:ZekeSetModel claude-3-sonnet " Switch to Claude Sonnet
:ZekeSetModel llama3:8b   " Switch to Llama 3
```

## 🌐 GhostLLM Integration

### Intelligent Routing
When using GhostLLM proxy, specify "auto" model for intelligent routing:

```vim
:ZekeSetProvider ghostllm
:ZekeSetModel auto
```

**Routing logic:**
- **Code completion** → GitHub Copilot or DeepSeek Coder
- **Complex reasoning** → Claude 3 Opus
- **Quick tasks** → GPT-3.5 Turbo or Llama 3
- **Cost-sensitive** → Local Ollama models first

### Fallback Chain
```lua
-- Configure fallback providers
routing = {
  primary = "auto",
  fallback = {"ollama:llama3", "openai:gpt-3.5-turbo", "anthropic:claude-3-haiku"}
}
```

## 🎪 Advanced Features

### Context-Aware Switching
Different tasks automatically suggest optimal providers:

```vim
:ZekeExplain        " Suggests: Claude (reasoning)
:ZekeEdit           " Suggests: GPT-4 (editing)
:ZekeAnalyze        " Suggests: Claude (analysis)
:ZekeCreate         " Suggests: Copilot (code gen)
```

### Smart Suggestions
The switcher shows recommendations:
```
🔌 Recommended for current task:
  ⭐ Claude 3 Sonnet (best for code explanation)
  ✅ GPT-4 (good general purpose)
  🏠 Llama 3 (privacy-focused local)
```

### Session Memory
```vim
" Remembers your last choice per context
:ZekeChat "explain this"     " Uses Claude (last reasoning choice)
:ZekeEdit "fix the bug"      " Uses GPT-4 (last editing choice)
:ZekeCreate "new component"  " Uses Copilot (last creation choice)
```

## 📊 Status Integration

### Status Line
Add to your status line to see current provider:
```lua
-- Status line integration
function ZekeStatus()
  local zeke = require('zeke')
  return zeke.get_status_line()  -- "⚡ openai:gpt-4"
end
```

### Visual Indicators
```vim
:ZekeStatus  " Show detailed connection status
```

Output:
```
⚡ Zeke Status:
├─ Provider: openai (✅ authenticated)
├─ Model: gpt-4
├─ Connection: WebSocket connected
├─ Session: zeke-cli-abc123
└─ Response time: 245ms
```

## 🔧 Configuration

### Default Providers
```lua
require("zeke").setup({
  -- Provider preference order
  provider_priority = {
    "ghostllm",    -- Intelligent routing first
    "github",      -- Copilot for code
    "anthropic",   -- Claude for reasoning
    "openai",      -- GPT for general
    "ollama"       -- Local for privacy
  },

  -- Model preferences per provider
  preferred_models = {
    openai = "gpt-4",
    anthropic = "claude-3-sonnet",
    ollama = "llama3:8b",
    github = "copilot"
  },

  -- Task-specific routing
  routing = {
    code_completion = "github",
    explanation = "anthropic",
    editing = "openai",
    analysis = "anthropic",
    creation = "github"
  }
})
```

### Switching Behavior
```lua
-- Customize switching behavior
switching = {
  confirm_expensive = true,      -- Confirm before using costly models
  auto_fallback = true,         -- Fall back if provider fails
  preserve_context = true,      -- Keep context when switching
  show_cost_estimates = true,   -- Show cost per request
}
```

## 🚨 Cost Management

### Cost Awareness
```vim
" Shows estimated cost before switching
:ZekeSetModel gpt-4
# Warning: GPT-4 costs ~$0.03/request. Continue? [y/N]

:ZekeSetModel llama3:8b
# ✅ Local model - no API costs
```

### Usage Tracking
```vim
:ZekeProviders  " Show cost breakdown per provider
```

Display:
```
💰 Today's Usage:
├─ OpenAI: $2.40 (12 requests)
├─ Anthropic: $1.80 (6 requests)
├─ GitHub: $0.00 (Pro subscription)
└─ Ollama: $0.00 (local)
```

## 🔄 Live Switching During Conversations

### Mid-Conversation Switching
```vim
" Start with one provider
:ZekeChat "Explain async Rust"

" Switch provider mid-conversation
<leader>zs  " Select different provider
" Context automatically transfers!
```

### Provider Comparison
```vim
" Ask the same question to multiple providers
:ZekeChat "Optimize this function"
<leader>zp  " Cycle to next provider
:ZekeChat "same"  " Reuse last question
```

## 🎯 Best Practices

### Optimal Provider Selection
- **📝 Code completion** → GitHub Copilot
- **🧠 Complex reasoning** → Claude 3 Opus/Sonnet
- **⚡ Quick edits** → GPT-3.5 Turbo
- **🔒 Sensitive code** → Local Ollama
- **💰 Cost-sensitive** → Ollama > GPT-3.5 > Claude Haiku

### Workflow Examples
```vim
" Privacy-first development
<leader>zs → Ollama → llama3:8b

" Maximum capability
<leader>zs → Anthropic → claude-3-opus

" Balanced cost/performance
<leader>zs → GhostLLM → auto

" Code-focused session
<leader>zs → GitHub → copilot
```

### Keyboard Shortcuts Summary
```vim
<leader>zs  # Quick switcher (recommended)
<leader>zp  # Cycle providers
<leader>zm  # Cycle models
<leader>za  # Authentication management
<leader>zP  # Full provider management UI
```

Ready to experience instant AI provider switching? Press `<leader>zs` and switch at the speed of thought! ⚡