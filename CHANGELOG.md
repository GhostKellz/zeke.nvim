# Changelog

All notable changes to zeke.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Inline Ghost Text Completions** - Real-time AI code suggestions displayed as ghost text inline
  - Tab to accept, Ctrl+] to dismiss
  - Ctrl+Right for word acceptance, Ctrl+Down for line acceptance
  - Alt+]/[ to cycle through multiple suggestions
  - Configurable debounce timing
  - Multi-line completion support
- **Chat Panel** - Beautiful floating window chat interface
  - Streaming responses in real-time
  - Separate input buffer with prompt-style UX
  - Message history with visual separators
  - Auto-scrolling to latest messages
  - Context attachment from current buffer
  - Commands: `:ZekeChatPanel`, `:ZekeChatOpen`, `:ZekeChatClose`, `:ZekeChatClear`
- **LSP Context Integration** - Deep LSP integration for intelligent assistance
  - Diagnostic detection and analysis
  - Hover information extraction
  - Document symbol awareness
  - `:ZekeFix` - AI-powered auto-fix for diagnostics at cursor
  - `:ZekeExplainDiagnostic` - Explain diagnostics in floating window
  - Context-aware completions based on LSP info
- **Smart Keybindings** - Intuitive AI assistance shortcuts
  - `<leader>aa` - Ask AI (quick prompt)
  - `<leader>af` - AI fix diagnostic
  - `<leader>ae` - AI edit selection (visual mode)
  - `<leader>ax` - AI explain code
  - `<leader>ac` - AI toggle chat panel
  - `<leader>at` - AI toggle completions
  - Fully configurable keymaps
- **Completion Module** - New `lua/zeke/completion/` module
  - `inline.lua` - Ghost text completion engine (548 lines)
  - `init.lua` - Completion module entry point
- **Chat Module** - New `lua/zeke/chat/` module
  - `panel.lua` - Chat panel UI implementation (314 lines)
- **LSP Module** - New `lua/zeke/lsp/` module
  - `context.lua` - LSP context gathering and operations (373 lines)
  - `init.lua` - LSP module entry point
- **Documentation**
  - `docs/FEATURES.md` - Comprehensive features documentation
  - `EXAMPLE_CONFIG.md` - Configuration examples and guide
  - `examples/complete-setup.md` - Complete setup examples

### Changed
- **CLI Integration** - Updated `lua/zeke/cli.lua`
  - Fixed `stream_chat()` to use correct `zeke chat --stream` command
  - Improved chunk handling with newline support
  - Better streaming callback architecture
- **Main Plugin** - Updated `lua/zeke/init.lua`
  - Integrated completion, chat panel, and LSP modules
  - Added new user commands for chat panel and LSP features
  - Enhanced keybindings with AI assistance shortcuts
  - Improved setup flow with module initialization

### Architecture
- Switched from HTTP API to CLI-based architecture
  - All features now use `zeke chat --stream` for responses
  - Better performance and reliability
  - Simplified deployment (no server needed)
- Modular structure for maintainability
  - Separate modules for completion, chat, and LSP
  - Clean separation of concerns
  - Easy to extend and customize

## [0.2.x] - Previous Releases

### Added
- ZekeCode agent interface
- Model management and cycling
- Multiple provider support (Ollama, OpenAI, Claude, Google, Copilot, xAI)
- GhostLang integration
- Diff preview functionality
- Selection tracking
- Basic CLI wrapper
- Health check commands
- Provider switching
- Configuration management

### Features from Earlier Versions
- `:ZekeCode` - Main AI agent interface
- `:ZekeChat` - Quick chat command
- `:ZekeEdit` - Edit buffer with AI
- `:ZekeExplain` - Explain code
- `:ZekeAnalyze` - Code analysis
- `:ZekeModels` - Model picker
- `:ZekeProviders` - Provider management
- Model cycling with Tab/Shift+Tab
- Ollama host management
- LiteLLM host management

## Comparison with Competitors

### vs. GitHub Copilot
- ✅ All Copilot features (inline completions, chat)
- ✅ Multiple AI providers (not locked to GitHub)
- ✅ Local AI support (Ollama)
- ✅ Full LSP integration
- ✅ Free and open source

### vs. Claude Code
- ✅ All Claude Code features (agent, streaming)
- ✅ Inline completions (Claude Code doesn't have)
- ✅ Better chat UX with floating panel
- ✅ Multiple AI providers
- ✅ Local AI support

## Future Plans

### Planned Features
- Telescope integration for chat history search
- Enhanced diff preview with side-by-side comparison
- Code action suggestions
- Refactoring tools
- Test generation
- Documentation generation
- Multi-file context support
- Project-wide code understanding
- Custom prompt templates
- Conversation export/import

### Under Consideration
- Pair programming mode with real-time collaboration
- Voice input support
- Integration with other AI services
- Plugin API for extensions
- Custom model fine-tuning support

---

For migration guides and detailed documentation, see:
- [Features Documentation](docs/FEATURES.md)
- [Configuration Examples](EXAMPLE_CONFIG.md)
- [README](README.md)
