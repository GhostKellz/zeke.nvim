# @-Mention Context System

Zeke.nvim supports Claude Code-style @-mentions to include contextual information in your AI prompts.

## Supported @-Mentions

### `@file:path/to/file`
Include the contents of a specific file in your prompt.

**Examples:**
```
Can you review @file:src/init.lua?
Explain how @file:lib/parser.rs works
```

**Keyboard Shortcut:** Press `<C-f>` in the input window to open a file picker.

### `@buffer`
Include the contents of the current buffer.

**Example:**
```
Can you refactor @buffer to use async/await?
```

### `@selection`
Include the current visual selection.

**Example:**
1. Select code in visual mode
2. Open ZekeCode (`:ZekeCode`)
3. Type: `Explain @selection`

### `@diag`
Include LSP diagnostics (errors, warnings) from the current buffer.

**Example:**
```
Fix @diag
Help me understand @diag
```

### `@git:diff`
Include the output of `git diff` (uncommitted changes).

**Example:**
```
Review @git:diff before I commit
Generate a commit message for @git:diff
```

### `@git:status`
Include the output of `git status --short`.

**Example:**
```
What files changed? @git:status
```

## Usage

### In ZekeCode Agent (`:ZekeCode`)

1. Open the agent interface: `:ZekeCode`
2. Type your message with @-mentions:
   ```
   Can you help refactor @file:src/main.zig and fix @diag?
   ```
3. Press `<CR>` to send

**Context Chips:** When you use @-mentions, you'll see visual chips showing what context is included:
```
Context: 📄 main.zig  │  🔍 Diagnostics
```

### In Regular Chat (`:ZekeChat`)

@-mentions work the same way in the chat panel.

### Programmatic Usage

You can also use the @-mention system programmatically in your own Lua scripts:

```lua
local mentions = require('zeke.mentions')

-- Parse a string
local text = "Explain @buffer and fix @diag"
local parsed = mentions.parse(text)
-- Returns: {
--   {type="buffer", raw="@buffer", start_pos=8, end_pos=15},
--   {type="diag", raw="@diag", start_pos=24, end_pos=29}
-- }

-- Resolve contexts
local resolved = mentions.resolve(parsed)
-- Returns: {
--   {type="buffer", content="...", metadata={...}},
--   {type="diag", content="...", metadata={...}}
-- }

-- Process text with context
local processed_text, mentions_found = mentions.process(text)
-- processed_text includes the original text + expanded context
```

## Context Format

When contexts are resolved, they're appended to your prompt in a structured format:

```
Your original message here

--- Context ---

[FILE: @file:src/init.lua]
```lua
-- File contents here
```

[DIAG: @diag]
```
Diagnostics:
  [ERROR] Line 42: undefined variable 'foo'
  [WARN] Line 58: unused parameter 'bar'
```

--- End Context ---
```

## Keyboard Shortcuts

| Key | Action | Context |
|-----|--------|---------|
| `<C-f>` | Open file picker for @file | Insert mode (input buffer) |
| `<CR>` | Send message with @-mentions | Normal mode (input buffer) |
| `<Tab>` | Cycle AI models | Normal mode |
| `<Esc>` | Close agent | Normal mode |
| `<C-l>` | Clear chat history | Normal mode |

## Tips

1. **Combine multiple contexts:**
   ```
   Review @file:src/auth.rs with these changes: @git:diff
   ```

2. **Reference specific files from errors:**
   ```
   I'm getting @diag in @buffer, can you help?
   ```

3. **Code review workflow:**
   ```
   Review @git:diff and suggest improvements
   ```

4. **Explain complex code:**
   ```
   Explain how @file:lib/parser.zig handles @selection
   ```

## Error Handling

If a context can't be resolved (e.g., file doesn't exist), you'll see a warning in the logs, but the request will still be sent with whatever contexts were successfully resolved.

Check logs with `:ZekeLog` or `:messages`.

## Configuration

Currently, @-mentions work out of the box with no configuration needed. The feature is automatically enabled when you load zeke.nvim.

Future configuration options may include:
- Custom mention patterns
- Context size limits
- Automatic context inclusion based on cursor position
- Context caching

## Implementation Details

The @-mention system consists of three main components:

1. **Parser** (`lua/zeke/mentions.lua`): Parses @-mentions from text
2. **Resolver**: Resolves mentions to actual content (file contents, diagnostics, etc.)
3. **UI** (`lua/zeke/ui/context_chips.lua`): Displays context chips

All parsing happens on the Neovim side before sending to the Zeke CLI, so the CLI receives the fully-expanded prompt with context.

## Comparison to Claude Code

| Feature | Claude Code | Zeke.nvim | Notes |
|---------|-------------|-----------|-------|
| @file | ✅ | ✅ | |
| @buffer | ✅ | ✅ | |
| @selection | ✅ | ✅ | |
| @diag | ✅ | ✅ | LSP diagnostics |
| @git:diff | ✅ | ✅ | |
| @git:status | ❌ | ✅ | Extra! |
| File picker | ✅ | ✅ | Telescope or vim.ui.select |
| Context chips | ✅ | ✅ | Visual indicators |
| Multi-provider | ❌ | ✅ | Works with all 7 providers! |

## See Also

- [Main README](../README.md)
- [Agent Interface](./agent.md)
- [LSP Context](./lsp.md)
