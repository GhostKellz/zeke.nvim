# 📚 Zeke.nvim Documentation

Welcome to the comprehensive documentation for **Zeke.nvim** - the most advanced AI coding assistant for Neovim.

## 🎯 Quick Navigation

### 🚀 Getting Started
- [Installation Guide](../README.md#-installation) - Set up Zeke.nvim in minutes
- [Configuration](../README.md#️-configuration) - Customize to your workflow

### 🔐 Authentication & Providers
- **[Authentication Guide](authentication.md)** - OAuth flows, API keys, and security
- **[Provider Switching](provider-switching.md)** - Instant provider and model switching
- **[GhostLLM Integration](ghostllm-integration.md)** - Unified proxy and intelligent routing

### ⚡ Advanced Features
- **[WebSocket Integration](websocket-integration.md)** - Real-time communication with Zeke CLI
- [Streaming Chat](streaming-chat.md) - Real-time markdown rendering *(coming soon)*
- [Context Management](context-management.md) - File, project, and git context *(coming soon)*

### 🛡️ Security & Enterprise
- [Consent Management](consent-management.md) - GhostWarden security system *(coming soon)*
- [Enterprise Deployment](enterprise.md) - Multi-user and compliance features *(coming soon)*
- [Audit & Logging](audit-logging.md) - Track AI operations *(coming soon)*

### 🔧 Development & Customization
- [Plugin Development](plugin-development.md) - Extend Zeke.nvim *(coming soon)*
- [API Reference](api-reference.md) - Complete function reference *(coming soon)*
- [Troubleshooting](troubleshooting.md) - Common issues and solutions *(coming soon)*

## 🌟 Feature Highlights

### ✅ **Revolutionary Features Available Now:**

#### 🔌 **Universal Provider Support**
Seamlessly work with **all major AI providers**:
- **GitHub Copilot Pro** - OAuth authentication for Pro subscriptions
- **Google Cloud AI** - Vertex AI, Gemini, and Grok access
- **OpenAI** - ChatGPT API with full feature support
- **Anthropic** - Claude models with API key authentication
- **Ollama** - Auto-detected local models for privacy
- **GhostLLM** - Unified proxy with intelligent routing

#### ⚡ **Instant Provider Switching**
```vim
<leader>zs   " Quick switcher popup
<leader>zp   " Cycle through providers
<leader>zm   " Cycle through models
```

No other Neovim AI plugin offers this level of provider flexibility.

#### 🛡️ **Enterprise-Grade Security**
- **GhostWarden Consent System** - Approve actions before execution
- **Granular Permissions** - Session, project, and one-time approvals
- **Audit Trails** - Complete logging of AI operations
- **Privacy Controls** - Local-first options with Ollama

#### 🌐 **Real-time Communication**
- **WebSocket Streaming** - Instant bidirectional communication
- **Auto-Discovery** - Find and connect to Zeke CLI automatically
- **Connection Resilience** - Robust reconnection and health monitoring
- **Context Intelligence** - Rich file, project, and git context

#### 🎛️ **Advanced Management**
- **Interactive UIs** - Beautiful popups for authentication and provider management
- **Cost Tracking** - Monitor API usage and spending
- **Performance Metrics** - Real-time latency and health statistics
- **Session Management** - Multiple concurrent Zeke CLI sessions

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                Neovim Frontend                      │
│  🎨 Lua UI • Commands • Keybindings • Real-time UI │
└─────────────────────┬───────────────────────────────┘
                      │ MLua Bindings
┌─────────────────────▼───────────────────────────────┐
│                 Rust Backend                       │
│  ⚡ Performance • WebSocket • Provider Management   │
└─────────────────────┬───────────────────────────────┘
                      │ WebSocket/HTTP
┌─────────────────────▼───────────────────────────────┐
│              Integration Layer                      │
│     🔧 Zeke CLI • GhostLLM • Provider APIs         │
└─────────────────────┬───────────────────────────────┘
                      │ API Calls
┌─────────────────────▼───────────────────────────────┐
│                AI Providers                        │
│  🤖 OpenAI • Claude • Copilot • Ollama • Google    │
└─────────────────────────────────────────────────────┘
```

### Why This Architecture Wins
- **🚀 Performance** - Rust backend for heavy operations
- **🎨 Flexibility** - Lua frontend for customization
- **🔄 Real-time** - WebSocket communication
- **🌐 Unified** - Single interface for all providers
- **🛡️ Secure** - Consent-based operation approval

## 🆚 Comparison with Other Plugins

| Feature | **Zeke.nvim** | claude-code.nvim | copilot.vim | codeium.vim |
|---------|---------------|------------------|-------------|-------------|
| **Multi-Provider** | ✅ All major providers | ❌ Claude only | ❌ GitHub only | ❌ Codeium only |
| **Browser OAuth** | ✅ GitHub + Google | ❌ Manual setup | ✅ GitHub only | ❌ Web signup |
| **Real-time Streaming** | ✅ WebSocket | ❌ HTTP polling | ❌ No streaming | ❌ No streaming |
| **Security Controls** | ✅ Consent system | ❌ Basic logging | ❌ No security | ❌ No security |
| **Provider Switching** | ✅ Instant | ❌ Restart required | ❌ Not supported | ❌ Not supported |
| **Local Models** | ✅ Ollama integration | ❌ Cloud only | ❌ Cloud only | ❌ Cloud only |
| **Performance** | ✅ Rust backend | ❌ Pure Lua | ❌ Vim script | ❌ Python |
| **Enterprise Ready** | ✅ Full audit trail | ❌ Basic features | ❌ Consumer focus | ❌ Basic |
| **Cost Management** | ✅ Tracking + limits | ❌ No tracking | ❌ No tracking | ❌ No tracking |
| **Context Intelligence** | ✅ Rich context | ❌ Basic | ❌ Basic | ❌ Basic |

## 🎮 Quick Start Commands

### Essential Commands
```vim
:ZekeAuth              " Manage authentication
:ZekeSwitcher          " Quick provider/model switcher
:ZekeChat "message"    " Chat with AI
:ZekeChatStream "msg"  " Real-time streaming chat
:ZekeConnect           " Auto-connect to Zeke CLI
```

### Provider Management
```vim
:ZekeAuthGitHub        " GitHub OAuth (Copilot Pro)
:ZekeAuthGoogle        " Google OAuth (Vertex AI)
:ZekeAuthOpenAI        " OpenAI API key setup
:ZekeProviders         " Full provider management UI
```

### Code Operations
```vim
:ZekeExplain           " Explain current code
:ZekeEdit "instruction" " AI-powered editing
:ZekeAnalyze security  " Code analysis
:ZekeCreate "component" " Generate new code
```

## 🔮 What's Coming Next

### 📋 **In Development**
- **Streaming Chat UI** - Real-time markdown rendering with syntax highlighting
- **Task Management** - Async operations with progress tracking and cancellation
- **Intelligent Caching** - Context-aware response caching for performance
- **Multi-file Refactoring** - AI-powered codebase transformations

### 🎯 **Planned Features**
- **Team Collaboration** - Shared sessions and contexts
- **Custom Model Training** - Fine-tune models on your codebase
- **Advanced Analytics** - Usage patterns and optimization insights
- **Plugin Ecosystem** - Third-party extensions and integrations

## 🤝 Community & Support

### Getting Help
- **[GitHub Issues](https://github.com/ghostkellz/zeke.nvim/issues)** - Bug reports and feature requests
- **[GitHub Discussions](https://github.com/ghostkellz/zeke.nvim/discussions)** - Questions and community support
- **[Discord Community](https://discord.gg/zeke)** - Real-time chat and support

### Contributing
- **[Contributing Guide](../CONTRIBUTING.md)** - How to contribute to the project
- **[Development Setup](../README.md#development-setup)** - Set up development environment
- **[Architecture Guide](architecture.md)** - Understand the codebase *(coming soon)*

### Staying Updated
- **[Changelog](../CHANGELOG.md)** - Latest updates and releases
- **[Release Notes](https://github.com/ghostkellz/zeke.nvim/releases)** - Detailed release information
- **[Roadmap](roadmap.md)** - Future development plans *(coming soon)*

## 📖 Documentation Status

| Document | Status | Description |
|----------|--------|-------------|
| [Authentication Guide](authentication.md) | ✅ Complete | OAuth flows, API keys, security |
| [Provider Switching](provider-switching.md) | ✅ Complete | Instant switching and management |
| [GhostLLM Integration](ghostllm-integration.md) | ✅ Complete | Unified proxy setup and usage |
| [WebSocket Integration](websocket-integration.md) | ✅ Complete | Real-time communication guide |
| Streaming Chat | 🚧 Coming Soon | Real-time UI and markdown rendering |
| Context Management | 🚧 Coming Soon | File, project, git context |
| Consent Management | 🚧 Coming Soon | GhostWarden security system |
| Enterprise Deployment | 🚧 Coming Soon | Multi-user and compliance |
| API Reference | 🚧 Coming Soon | Complete function reference |
| Troubleshooting | 🚧 Coming Soon | Common issues and solutions |

---

## 🎉 **Welcome to the Future of AI Coding**

**Zeke.nvim** isn't just another AI plugin - it's a complete reimagining of how AI should integrate with your development workflow. With **universal provider support**, **enterprise-grade security**, **real-time streaming**, and **intelligent routing**, we've built the tool that every serious developer deserves.

**Ready to experience the revolution?** Start with our [Installation Guide](../README.md#-installation) and join thousands of developers who've already made the switch to the future of AI-assisted coding.

---

<div align="center">

**[⭐ Star us on GitHub](https://github.com/ghostkellz/zeke.nvim)** • **[🚀 Get Started](../README.md#-installation)** • **[💬 Join Community](https://discord.gg/zeke)**

*Built with ❤️ by developers who actually use AI coding tools*

</div>