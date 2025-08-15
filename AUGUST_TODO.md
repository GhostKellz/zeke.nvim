# AUGUST_TODO.md - Weekend Goals for zeke.nvim

## 🎯 Project Status
- **Current State**: Basic Zig CLI and Neovim plugin structure complete
- **Goal**: Make zeke.nvim work identically to claude-code.nvim but with pure Zig for speed
- **Reference**: [claude-code.nvim](https://github.com/greggh/claude-code.nvim)

## 🚀 Weekend Priorities (High Impact)

### 1. Core Terminal Integration Enhancement
- [ ] **Fix config.get().cmd path resolution** - Currently hardcoded to 'zeke', should use 'zeke_nvim' binary
- [ ] **Implement floating window configuration** - Add split_ratio, position options (float, split, etc.)
- [ ] **Add window navigation keymaps** - Implement focus/toggle functionality like `<C-w>w`
- [ ] **Auto-enter insert mode option** - Like claude-code.nvim's `enter_insert` setting

### 2. Real AI Integration (Critical Missing Feature)
- [ ] **Replace mock responses with actual AI API calls** - Integrate OpenAI/Anthropic/local model
- [ ] **Add streaming response support** - Real-time AI output like Claude Code
- [ ] **Implement proper error handling** - Network timeouts, API errors, etc.
- [ ] **Add API key configuration** - Environment variables and config file support

### 3. File Handling & Auto-Reload System
- [ ] **Implement file watching mechanism** - Auto-reload when zeke modifies files
- [ ] **Add git root detection** - Start zeke in project root like claude-code.nvim
- [ ] **Buffer update notifications** - Show when files are modified externally
- [ ] **Backup/undo integration** - Save state before AI modifications

## 🛠️ Technical Improvements

### Zig CLI Enhancements
- [ ] **Add proper command parsing** - Better argument handling for complex instructions
- [ ] **Implement RPC mode** - `--rpc` flag for editor integration
- [ ] **Add streaming JSON output** - For real-time response display
- [ ] **Optimize binary size** - ReleaseFast build optimizations

### Lua Plugin Polish
- [ ] **Add which-key integration** - Descriptive command names
- [ ] **Implement visual mode selection** - Edit/explain selected code
- [ ] **Add command history** - Remember recent AI interactions  
- [ ] **Create status line integration** - Show zeke activity status

### Configuration System
- [ ] **Add comprehensive setup options** - Match claude-code.nvim feature parity
- [ ] **Implement config validation** - Check for required dependencies
- [ ] **Add lazy loading support** - Only load when needed
- [ ] **Create example configurations** - For different use cases

## 🔧 Missing Core Features

### Command Variants
- [ ] **Implement `--continue` flag** - Continue previous conversation
- [ ] **Add `--verbose` mode** - Detailed AI reasoning output
- [ ] **Create `--diff` output** - Show changes before applying
- [ ] **Support custom prompts** - User-defined AI instructions

### Window Management
- [ ] **Add window position options** - `botright`, `topleft`, `vertical`, `float`
- [ ] **Implement resize handling** - Dynamic window sizing
- [ ] **Create split ratio configuration** - Adjustable terminal size
- [ ] **Add border customization** - Match user's theme

### Performance & UX
- [ ] **Add loading indicators** - Show AI processing status
- [ ] **Implement request queuing** - Handle multiple simultaneous requests
- [ ] **Create interrupt handling** - Cancel long-running requests
- [ ] **Add response caching** - Avoid duplicate API calls

## 🎨 UI/UX Enhancements

### Response Display
- [ ] **Syntax highlighting** - Pretty-print code in responses
- [ ] **Markdown rendering** - Format AI explanations nicely
- [ ] **Code block extraction** - Easy copy/apply for code suggestions
- [ ] **Interactive diff view** - Review changes before applying

### Terminal Experience
- [ ] **Custom terminal title** - Show current AI task
- [ ] **Progress indicators** - Visual feedback for long operations
- [ ] **Command completion** - Tab completion for zeke commands
- [ ] **Session persistence** - Remember conversation context

## 🧪 Advanced Features (Stretch Goals)

### AI Workflow Integration
- [ ] **Code review mode** - AI-assisted code review workflow
- [ ] **Test generation** - Auto-generate unit tests
- [ ] **Documentation generator** - Create docs from code
- [ ] **Refactoring assistant** - Large-scale code restructuring

### Developer Experience
- [ ] **Plugin debugging mode** - Verbose logging and inspection
- [ ] **Performance profiling** - Track response times and usage
- [ ] **Custom AI models** - Support for local/alternative models
- [ ] **Collaborative features** - Share AI sessions with team

## 🐛 Current Issues to Fix

### High Priority Bugs
- [ ] **JSON parsing errors** - Handle malformed AI responses gracefully
- [ ] **Terminal buffer cleanup** - Properly close floating windows
- [ ] **Keymap conflicts** - Ensure no conflicts with user bindings
- [ ] **Memory leaks** - Clean up Zig allocations properly

### Medium Priority Issues
- [ ] **Cross-platform compatibility** - Test on macOS/Windows
- [ ] **Neovim version compatibility** - Support older versions if possible
- [ ] **Plugin conflicts** - Test with popular plugin combinations
- [ ] **Error message clarity** - Better user-facing error messages

## ⚡ Weekend Implementation Strategy

### Friday Evening (Setup)
1. Fix basic configuration and binary path issues
2. Set up AI API integration skeleton
3. Test current functionality end-to-end

### Saturday (Core Features)
1. Implement real AI API calls with streaming
2. Add file watching and auto-reload system  
3. Enhance terminal window management
4. Add visual mode selection support

### Sunday (Polish & Testing)
1. Add proper error handling and loading states
2. Implement command variants (--continue, --verbose)
3. Test with real projects and workflows
4. Create documentation and examples

### Sunday Evening (Validation)
1. Compare feature parity with claude-code.nvim
2. Performance testing and optimization
3. Create demo video/screenshots
4. Plan next iteration based on weekend learnings

## 📋 Success Criteria

By end of weekend, zeke.nvim should:
- ✅ Have real AI integration (not mocked responses)
- ✅ Auto-reload files when AI modifies them
- ✅ Support floating and split window modes
- ✅ Handle visual selections for edit/explain
- ✅ Provide streaming responses with loading states
- ✅ Match claude-code.nvim's core user experience
- ✅ Be demonstrably faster due to Zig backend

## 🎯 Post-Weekend Goals

### Week 1 After Weekend
- [ ] **Add comprehensive documentation**
- [ ] **Set up CI/CD for releases**
- [ ] **Create installation guide**
- [ ] **Gather user feedback**

### Long-term Vision
- [ ] **Plugin ecosystem integration** (telescope, which-key, etc.)
- [ ] **Performance benchmarking** vs other AI plugins
- [ ] **Community building** and contribution guidelines
- [ ] **Advanced AI features** (multi-model support, custom prompts)

---

**Remember**: Focus on speed and user experience. The Zig backend should provide noticeably better performance than Node.js based alternatives while maintaining feature parity with claude-code.nvim.