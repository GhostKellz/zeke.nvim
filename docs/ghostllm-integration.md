# 🌐 GhostLLM Integration

GhostLLM provides a unified proxy layer that intelligently routes requests across all AI providers, offering cost optimization, performance improvements, and enterprise-grade features.

## 🎯 Why GhostLLM?

### Unified API Layer
- **One interface** for all AI providers
- **Intelligent routing** based on task type and cost
- **Automatic fallbacks** when providers fail
- **Cost optimization** through smart model selection

### Enterprise Features
- **Rate limiting** and quota management
- **Request/response caching** for efficiency
- **Audit logging** for compliance
- **User authentication** and authorization

## 🚀 Quick Setup

### 1. Install GhostLLM
```bash
# Clone and install GhostLLM
git clone https://github.com/ghostkellz/ghostllm
cd ghostllm
cargo install --path .

# Or use precompiled binary
curl -sSL https://github.com/ghostkellz/ghostllm/releases/latest/download/ghostllm-linux | sudo tee /usr/local/bin/ghostllm
sudo chmod +x /usr/local/bin/ghostllm
```

### 2. Start GhostLLM Proxy
```bash
# Development mode (auto-reload)
ghostllm serve --dev

# Production mode
ghostllm serve --port 8080

# With specific providers
ghostllm serve --providers openai,anthropic,ollama
```

### 3. Configure Zeke.nvim
```lua
require("zeke").setup({
  default_provider = "ghostllm",
  default_model = "auto",

  ghostllm = {
    base_url = "http://localhost:8080",
    enable_consent = true,
    auto_approve_read = true,
    auto_approve_write = false,
  }
})
```

### 4. Authenticate with GhostLLM
```vim
:ZekeAuth  " Interactive setup
" Or connect directly:
:ZekeAuthGhostLLM http://localhost:8080
```

## 🎛️ Intelligent Routing

### Automatic Model Selection
```vim
:ZekeSetModel auto  " Let GhostLLM choose optimal model
```

**Routing logic:**
- **Code completion** → `github:copilot` or `ollama:deepseek-coder`
- **Complex reasoning** → `anthropic:claude-3-opus`
- **Quick tasks** → `openai:gpt-3.5-turbo` or `ollama:llama3`
- **Cost-sensitive** → Local models first, then cheapest cloud

### Task-Specific Routing
```vim
:ZekeEdit "optimize this function"    " → GPT-4 (good at code editing)
:ZekeExplain                          " → Claude Sonnet (best reasoning)
:ZekeAnalyze security                 " → Claude Opus (thorough analysis)
:ZekeCreate "React component"         " → GitHub Copilot (code generation)
```

### Custom Routing Rules
Configure in `~/.config/ghostllm/routing.toml`:
```toml
[routing]
# Prefer local models for code completion
code_completion = "ollama:deepseek-coder"

# Use cloud models for complex reasoning
reasoning = "anthropic:claude-3-sonnet"

# Quick tasks use efficient models
quick_tasks = "openai:gpt-3.5-turbo"

# Fallback chain
fallback = ["ollama:llama3", "openai:gpt-3.5-turbo", "anthropic:claude-3-haiku"]

[costs]
# Set cost limits
daily_limit_usd = 10.00
warn_threshold_usd = 8.00
```

## 🛡️ Security & Consent

### GhostWarden Integration
GhostLLM includes GhostWarden for consent-based AI interactions:

```vim
# When AI requests file access:
┌─────────────────────────────────────┐
│    🛡️ GhostWarden Security Alert    │
├─────────────────────────────────────┤
│ 🤖 AI requesting permission to:     │
│ 📖 Read file: config/app.py        │
│ ⚠️  Risk Level: Low                 │
│                                     │
│ 🔐 Choose response:                 │
│ [1] Allow Once                     │
│ [2] Allow Session                  │
│ [3] Allow Project                  │
│ [d] Deny                           │
└─────────────────────────────────────┘
```

### Consent Levels
- **Allow Once** - Single operation approval
- **Allow Session** - Approve for current Neovim session
- **Allow Project** - Approve for current project (saved to `.zeke-consents.json`)
- **Deny** - Block the operation

### Auto-Approval Rules
```lua
ghostllm = {
  enable_consent = true,
  auto_approve_read = true,    -- Auto-approve read operations
  auto_approve_write = false,  -- Always ask for write operations

  -- Custom rules
  auto_approve_patterns = {
    "*.md",     -- Auto-approve markdown files
    "test/*",   -- Auto-approve test files
  }
}
```

## 💰 Cost Management

### Real-time Cost Tracking
```vim
:ZekeProviders  " View cost breakdown
```

Display:
```
💰 Cost Tracking:
├─ Today: $3.20
├─ This week: $18.50
├─ This month: $67.30
└─ Projected monthly: $89.40

📊 Provider breakdown:
├─ OpenAI: $45.20 (67%)
├─ Anthropic: $18.30 (27%)
├─ GitHub: $0.00 (Pro sub)
└─ Ollama: $0.00 (local)
```

### Cost Optimization
```vim
# GhostLLM automatically:
# 1. Routes simple tasks to cheaper models
# 2. Uses local models when possible
# 3. Caches responses to avoid duplicate calls
# 4. Warns before expensive operations

:ZekeSetModel claude-3-opus
# ⚠️ Warning: Claude Opus costs $15/1M tokens. Continue? [y/N]
```

### Usage Alerts
```vim
# When approaching limits:
🚨 Cost Alert: $8.50/$10.00 daily limit reached (85%)
💡 Consider switching to local models or lower-cost alternatives
```

## ⚡ Performance Features

### Response Caching
```bash
# Configure caching in ghostllm.toml
[caching]
enabled = true
ttl_seconds = 3600
max_size_mb = 100

# Cache similar requests automatically
[caching.rules]
code_explanation = 7200  # Cache explanations for 2 hours
simple_questions = 1800  # Cache simple Q&A for 30 minutes
```

### Request Batching
```lua
-- Multiple related requests batched together
:ZekeAnalyze quality     # \
:ZekeAnalyze security    # ├─ Batched into single API call
:ZekeAnalyze performance # /
```

### Load Balancing
```bash
# Multiple provider endpoints for redundancy
[providers.openai]
endpoints = [
  "https://api.openai.com/v1",
  "https://oai.hconeai.com/v1"  # Backup endpoint
]
```

## 📊 Monitoring & Analytics

### Request Analytics
```vim
:ZekeStatus  " Detailed statistics
```

Output:
```
📊 GhostLLM Analytics:
├─ Requests today: 127
├─ Average response time: 1.2s
├─ Cache hit rate: 34%
├─ Cost savings: $2.80 (cache)
└─ Most used model: gpt-3.5-turbo (45%)

🔗 Provider health:
├─ OpenAI: ✅ 99.8% uptime (245ms avg)
├─ Anthropic: ✅ 99.9% uptime (312ms avg)
├─ Ollama: ✅ Local (45ms avg)
└─ GitHub: ✅ 100% uptime (180ms avg)
```

### Health Monitoring
```bash
# Check GhostLLM health endpoint
curl http://localhost:8080/health

{
  "status": "healthy",
  "providers": {
    "openai": "healthy",
    "anthropic": "healthy",
    "ollama": "healthy"
  },
  "uptime": "2d 14h 32m",
  "requests_served": 1247
}
```

## 🔧 Advanced Configuration

### Provider Priorities
```toml
# ~/.config/ghostllm/config.toml
[routing]
# Fallback order when auto-routing
priority = [
  "ollama",      # Try local first
  "openai",      # Then OpenAI
  "anthropic",   # Then Anthropic
  "github"       # GitHub last
]

# Model preferences per provider
[models]
openai_preferred = "gpt-4"
anthropic_preferred = "claude-3-sonnet"
ollama_preferred = "llama3:8b"
```

### Custom Endpoints
```toml
[providers.openai]
base_url = "https://api.openai.com/v1"
api_key_env = "OPENAI_API_KEY"

[providers.anthropic]
base_url = "https://api.anthropic.com/v1"
api_key_env = "ANTHROPIC_API_KEY"

[providers.ollama]
base_url = "http://localhost:11434/v1"
# No API key needed for local Ollama

[providers.custom]
base_url = "https://your-custom-api.com/v1"
api_key_env = "CUSTOM_API_KEY"
```

## 🐛 Troubleshooting

### Connection Issues
```bash
# Check if GhostLLM is running
curl http://localhost:8080/health

# Check logs
ghostllm serve --log-level debug

# Test provider connections
ghostllm test-providers
```

### Authentication Problems
```vim
:ZekeAuth  " Reconfigure authentication

# Or check GhostLLM auth status
curl http://localhost:8080/auth/status
```

### Performance Issues
```bash
# Check cache statistics
curl http://localhost:8080/stats

# Clear cache if needed
curl -X DELETE http://localhost:8080/cache

# Restart with more memory
ghostllm serve --cache-size 500MB
```

## 🔄 Migration from Direct Providers

### Step 1: Install GhostLLM
```bash
ghostllm serve --port 8080
```

### Step 2: Update Zeke Configuration
```lua
-- Before: Direct provider access
require("zeke").setup({
  default_provider = "openai",
  api_keys = {
    openai = "sk-...",
    anthropic = "..."
  }
})

-- After: GhostLLM proxy
require("zeke").setup({
  default_provider = "ghostllm",
  default_model = "auto",
  ghostllm = {
    base_url = "http://localhost:8080"
  }
})
```

### Step 3: Migrate API Keys
```bash
# Set up API keys in GhostLLM
ghostllm auth set openai sk-your-key
ghostllm auth set anthropic your-key

# Test configuration
ghostllm test-providers
```

### Step 4: Verify Integration
```vim
:ZekeAuth           " Should show GhostLLM connected
:ZekeSetModel auto  " Enable intelligent routing
:ZekeChat "test"    " Test the integration
```

## 🎯 Best Practices

### Development Workflow
1. **Start with local models** (Ollama) for privacy
2. **Use auto-routing** for optimal model selection
3. **Set cost limits** to prevent overspending
4. **Enable caching** for repeated requests
5. **Monitor usage** regularly

### Production Deployment
1. **Use dedicated GhostLLM instance**
2. **Configure load balancing** for redundancy
3. **Set up monitoring** and alerting
4. **Enable audit logging** for compliance
5. **Implement backup strategies**

### Security Considerations
1. **Enable GhostWarden consent** for all operations
2. **Use project-level permissions** for team environments
3. **Regular token rotation** for API keys
4. **Monitor access logs** for unusual activity
5. **Encrypt sensitive data** at rest

Ready to experience unified AI with GhostLLM? Start with `ghostllm serve --dev` and unlock the full potential of multi-provider AI! 🌐