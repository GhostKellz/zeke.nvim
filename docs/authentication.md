# 🔐 Authentication Guide

Zeke.nvim provides enterprise-grade authentication for all major AI providers with browser-based OAuth flows and secure API key management.

## 🚀 Quick Start

```vim
:ZekeAuth  " Interactive authentication management UI
```

## 🔌 Supported Providers

### 🐙 GitHub Copilot Pro
**OAuth Browser Flow** - Professional GitHub subscriptions with enhanced features

```vim
:ZekeAuthGitHub
```

**What happens:**
1. Opens device code flow in your default browser
2. Authenticates with GitHub OAuth
3. Checks for Copilot Pro subscription
4. Enables enhanced Copilot features

**Requirements:**
- GitHub Pro, Team, or Enterprise subscription
- Active GitHub Copilot subscription

### 🌐 Google Cloud AI
**OAuth Browser Flow** - Access to Vertex AI, Gemini, and Grok

```vim
:ZekeAuthGoogle
```

**Services included:**
- **Vertex AI** - Enterprise AI platform
- **Gemini** - Google's latest language model
- **Grok** - Advanced reasoning capabilities

**Requirements:**
- Google Cloud Platform account
- Enabled AI APIs in your GCP project

### 🧠 OpenAI
**API Key Authentication** - ChatGPT and GPT models

```vim
:ZekeAuthOpenAI sk-your-api-key [optional-org-id]
```

**Supported models:**
- GPT-4, GPT-4 Turbo
- GPT-3.5 Turbo
- Organization support for enterprise accounts

### 🤖 Anthropic Claude
**API Key Authentication** - Claude family models

```vim
:ZekeAuthAnthropic your-anthropic-api-key
```

**Supported models:**
- Claude 3 Opus (most capable)
- Claude 3 Sonnet (balanced)
- Claude 3 Haiku (fastest)

### 🏠 Ollama (Local)
**Auto-Detection** - Privacy-first local models

```bash
# Just run Ollama and we'll detect it
ollama serve
```

**Auto-detected models:**
- Llama 3, CodeLlama
- DeepSeek Coder
- Mistral, Mixtral
- Custom fine-tuned models

### 🌐 GhostLLM Proxy
**Unified Access** - Route through intelligent proxy

```vim
:ZekeAuth  " Use interactive UI to configure
```

**Configuration:**
- Base URL (default: http://localhost:8080)
- Session token (optional)
- Fallback provider chain

## 🛡️ Security Features

### Secure Storage
- **API keys encrypted** using system keychain
- **Session tokens** stored securely
- **No plaintext credentials** in config files

### OAuth Flow Security
- **Device code flow** - no client secrets needed
- **Scope limitation** - minimal required permissions
- **Token expiration** - automatic refresh handling

### Privacy Controls
- **Local-first option** with Ollama
- **No telemetry** - your data stays private
- **Audit logging** - track all API usage

## 🎛️ Management UI

### Interactive Authentication
```vim
:ZekeAuth
```

**Features:**
- View authentication status for all providers
- Quick setup for each provider type
- Test connections and validate credentials
- Manage session tokens and API keys

### Provider Status
Each provider shows:
- ✅ **Authentication status** (connected/disconnected)
- 👤 **User information** (when available)
- 🕒 **Last used timestamp**
- ⏰ **Token expiration** (for OAuth)
- 💰 **Usage statistics** (when available)

## 🔧 Configuration

### Environment Variables
```bash
# API Keys (alternative to interactive setup)
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="..."
export GITHUB_TOKEN="ghp_..."

# GhostLLM Configuration
export GHOSTLLM_URL="http://localhost:8080"
export GHOSTLLM_SESSION_TOKEN="..."

# Ollama Configuration
export OLLAMA_HOST="http://localhost:11434"
```

### Lua Configuration
```lua
require("zeke").setup({
  -- Authentication will use these as fallbacks
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
    anthropic = vim.env.ANTHROPIC_API_KEY,
    github = vim.env.GITHUB_TOKEN,
  },

  -- GhostLLM proxy settings
  ghostllm = {
    base_url = "http://localhost:8080",
    session_token = nil, -- Auto-managed
    enable_consent = true,
  },
})
```

## 🚨 Troubleshooting

### "Authentication failed"
1. Check internet connection
2. Verify API key is valid and active
3. Ensure required scopes/permissions
4. Check provider service status

### "Browser not opening"
1. Set default browser in your OS
2. Try manual URL copy/paste
3. Use `xdg-open` (Linux) or `open` (macOS) command

### "Ollama not detected"
1. Ensure Ollama is running: `ollama serve`
2. Check port availability (default: 11434)
3. Verify firewall settings
4. Try custom URL in configuration

### "GhostLLM connection failed"
1. Start GhostLLM proxy server
2. Check port configuration (default: 8080)
3. Verify network connectivity
4. Review proxy logs for errors

## 🔄 Token Refresh

### Automatic Refresh
- **OAuth tokens** refresh automatically before expiration
- **API keys** validated on first use
- **Session tokens** managed by GhostLLM proxy

### Manual Refresh
```vim
:ZekeAuth              " Re-authenticate any provider
:ZekeAuthGitHub        " Refresh GitHub OAuth
:ZekeAuthGoogle        " Refresh Google OAuth
```

## 🏢 Enterprise Setup

### Multi-User Environments
- **Shared GhostLLM proxy** for team access
- **Individual authentication** per developer
- **Centralized logging** and audit trails
- **Cost tracking** per user/project

### SSO Integration
- **GitHub Enterprise** OAuth
- **Google Workspace** OAuth
- **Custom OIDC providers** via GhostLLM

### Compliance
- **SOC 2** compatible logging
- **GDPR** compliant data handling
- **HIPAA** ready with local models
- **Audit trails** for all AI operations

## 📱 Mobile/Remote Development

### VS Code Tunnels
- Authentication persists across tunnel sessions
- Secure token transmission
- Local storage encryption

### SSH/Remote
- Agent forwarding for OAuth flows
- Port forwarding for local services
- Secure credential synchronization

---

## 🎯 Best Practices

1. **Use OAuth when available** - more secure than API keys
2. **Enable GhostLLM proxy** - unified access and intelligent routing
3. **Configure local Ollama** - privacy-first development
4. **Set usage limits** - prevent unexpected API costs
5. **Regular token rotation** - maintain security hygiene
6. **Monitor audit logs** - track AI usage patterns

Ready to authenticate? Start with `:ZekeAuth` and experience enterprise-grade AI authentication in Neovim! 🚀