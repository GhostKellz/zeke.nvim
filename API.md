# 📚 API Reference

Complete API reference for **zeke.nvim** functions and methods.

## 📖 Table of Contents

- [🎯 Core AI Functions](#-core-ai-functions)
- [💬 Chat Interface](#-chat-interface)
- [📁 Context Management](#-context-management)
- [🤖 Provider Management](#-provider-management)
- [🔧 Diff and Preview](#-diff-and-preview)
- [⚙️ Configuration](#️-configuration)
- [📋 Task Management](#-task-management)
- [🔍 Utilities](#-utilities)
- [📝 Type Definitions](#-type-definitions)

## 🎯 Core AI Functions

### `require('zeke').chat(message)`

Send a message to the AI and get a response.

**Parameters:**
- `message` (string, optional): The message to send. If not provided, opens chat UI.

**Returns:**
- `nil`: Displays response in terminal or opens chat UI

**Example:**
```lua
local zeke = require('zeke')

-- Send a message
zeke.chat("Explain async/await in Rust")

-- Open chat UI
zeke.chat()  -- or zeke.chat("")
```

### `require('zeke').edit(instruction)`

Edit the current buffer with AI assistance.

**Parameters:**
- `instruction` (string, optional): How to modify the code. If not provided, prompts for input.

**Returns:**
- `nil`: Shows diff view with changes

**Example:**
```lua
local zeke = require('zeke')

-- Edit with instruction
zeke.edit("Add error handling to this function")

-- Prompt for instruction
zeke.edit()
```

### `require('zeke').explain(code)`

Get an explanation of code.

**Parameters:**
- `code` (string, optional): Code to explain. If not provided, uses current buffer.

**Returns:**
- `nil`: Displays explanation

**Example:**
```lua
local zeke = require('zeke')

-- Explain current buffer
zeke.explain()

-- Explain specific code
zeke.explain("fn main() { println!('Hello'); }")
```

### `require('zeke').create(description)`

Create a new file with AI assistance.

**Parameters:**
- `description` (string, optional): What to create. If not provided, prompts for input.

**Returns:**
- `nil`: Shows preview window with generated content

**Example:**
```lua
local zeke = require('zeke')

-- Create with description
zeke.create("REST API client in Rust using reqwest")

-- Prompt for description
zeke.create()
```

### `require('zeke').analyze(analysis_type, code)`

Analyze code for issues or improvements.

**Parameters:**
- `analysis_type` (string, optional): Type of analysis ('quality', 'performance', 'security'). Defaults to 'quality'.
- `code` (string, optional): Code to analyze. If not provided, uses current buffer.

**Returns:**
- `nil`: Displays analysis results

**Example:**
```lua
local zeke = require('zeke')

-- Analyze current buffer for security issues
zeke.analyze('security')

-- Analyze specific code for performance
zeke.analyze('performance', "for i in range(1000000): print(i)")
```

## 💬 Chat Interface

### `require('zeke').toggle_chat()`

Toggle the floating chat window.

**Parameters:**
- None

**Returns:**
- `nil`

**Example:**
```lua
local zeke = require('zeke')

-- Toggle chat window
zeke.toggle_chat()
```

### `require('zeke').save_conversation()`

Save the current conversation to history.

**Parameters:**
- None

**Returns:**
- `nil`

**Example:**
```lua
local zeke = require('zeke')

-- Save current chat
zeke.save_conversation()
```

### `require('zeke').list_conversations()`

Show a list of saved conversations and allow loading one.

**Parameters:**
- None

**Returns:**
- `nil`: Opens selection UI

**Example:**
```lua
local zeke = require('zeke')

-- Browse conversation history
zeke.list_conversations()
```

### `require('zeke').chat_stream(message)`

Start a streaming chat session.

**Parameters:**
- `message` (string, optional): Initial message. If not provided, prompts for input.

**Returns:**
- `nil`: Opens streaming response window

**Example:**
```lua
local zeke = require('zeke')

-- Stream response
zeke.chat_stream("Write a detailed explanation of closures")
```

## 📁 Context Management

### `require('zeke').add_current_file_to_context()`

Add the current file to the AI context.

**Parameters:**
- None

**Returns:**
- `nil`

**Example:**
```lua
local zeke = require('zeke')

-- Add current file to context
zeke.add_current_file_to_context()
```

### `require('zeke').add_file_to_context(filepath)`

Add a specific file to the AI context.

**Parameters:**
- `filepath` (string, optional): Path to file. If not provided, opens file picker.

**Returns:**
- `nil`

**Example:**
```lua
local zeke = require('zeke')

-- Add specific file
zeke.add_file_to_context("/path/to/file.lua")

-- Open file picker
zeke.add_file_to_context()
```

### `require('zeke').add_selection_to_context()`

Add the current visual selection to context.

**Parameters:**
- None

**Returns:**
- `nil`

**Note:** Must be called while in visual mode or with an active selection.

**Example:**
```lua
local zeke = require('zeke')

-- In visual mode, add selection
vim.keymap.set('v', '<leader>zs', function()
  zeke.add_selection_to_context()
end)
```

### `require('zeke').show_context()`

Display a summary of the current context.

**Parameters:**
- None

**Returns:**
- `string`: Context summary

**Example:**
```lua
local zeke = require('zeke')

-- Show context info
zeke.show_context()
-- Output: "3 files, 245 lines, 8.2KB"
```

### `require('zeke').clear_context()`

Remove all files from the AI context.

**Parameters:**
- None

**Returns:**
- `nil`

**Example:**
```lua
local zeke = require('zeke')

-- Clear all context
zeke.clear_context()
```

### `require('zeke').show_context_files()`

Show a list of files in context and allow removing them.

**Parameters:**
- None

**Returns:**
- `nil`: Opens selection UI

**Example:**
```lua
local zeke = require('zeke')

-- Manage context files
zeke.show_context_files()
```

### `require('zeke').workspace_search(query)`

Search for files in the workspace and add them to context.

**Parameters:**
- `query` (string, optional): Search query. If not provided, prompts for input.

**Returns:**
- `nil`: Shows search results

**Example:**
```lua
local zeke = require('zeke')

-- Search for config files
zeke.workspace_search("config")

-- Prompt for search term
zeke.workspace_search()
```

## 🤖 Provider Management

### `require('zeke').set_provider(provider)`

Switch to a different AI provider.

**Parameters:**
- `provider` (string, optional): Provider name ('openai', 'claude', 'copilot', 'ollama'). If not provided, shows selection.

**Returns:**
- `nil`

**Example:**
```lua
local zeke = require('zeke')

-- Switch to Ollama
zeke.set_provider('ollama')

-- Show provider selection
zeke.set_provider()
```

### `require('zeke').list_models()`

Get a list of available models for the current provider.

**Parameters:**
- None

**Returns:**
- `table`: Array of model names

**Example:**
```lua
local zeke = require('zeke')

-- Get available models
local models = zeke.list_models()
for _, model in ipairs(models) do
  print(model)
end
```

### `require('zeke').set_model(model)`

Set the active model for the current provider.

**Parameters:**
- `model` (string, optional): Model name. If not provided, prompts for input.

**Returns:**
- `nil`

**Example:**
```lua
local zeke = require('zeke')

-- Set specific model
zeke.set_model('gpt-4')

-- Prompt for model selection
zeke.set_model()
```

### `require('zeke').get_current_model()`

Get the currently active model.

**Parameters:**
- None

**Returns:**
- `string`: Current model name

**Example:**
```lua
local zeke = require('zeke')

-- Get current model
local model = zeke.get_current_model()
print("Current model: " .. model)
```

## 🔧 Diff and Preview

### Diff View (Automatic)

The diff view is automatically shown when using `edit()`. It provides these controls:

**In Diff View:**
- `a`: Accept changes and apply to buffer
- `r`: Reject changes and discard
- `q` or `<Esc>`: Close diff view

### Preview Window (Automatic)

The preview window is shown when using `create()`. It provides these controls:

**In Preview Window:**
- `s`: Save file with specified name
- `q` or `<Esc>`: Cancel and discard

## ⚙️ Configuration

### `require('zeke').setup(opts)`

Configure the plugin with options.

**Parameters:**
- `opts` (table): Configuration options (see [CONFIG.md](CONFIG.md) for details)

**Returns:**
- `nil`

**Example:**
```lua
require('zeke').setup({
  default_provider = 'openai',
  default_model = 'gpt-4',
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
  },
  keymaps = {
    chat = '<leader>zc',
    edit = '<leader>ze',
  },
})
```

## 📋 Task Management

### `require('zeke').list_tasks()`

Show a list of active background tasks.

**Parameters:**
- None

**Returns:**
- `nil`: Displays task list

**Example:**
```lua
local zeke = require('zeke')

-- Show active tasks
zeke.list_tasks()
```

### `require('zeke').cancel_task(task_id)`

Cancel a specific background task.

**Parameters:**
- `task_id` (number, optional): Task ID to cancel. If not provided, prompts for input.

**Returns:**
- `nil`

**Example:**
```lua
local zeke = require('zeke')

-- Cancel specific task
zeke.cancel_task(1)

-- Prompt for task ID
zeke.cancel_task()
```

### `require('zeke').cancel_all_tasks()`

Cancel all active background tasks.

**Parameters:**
- None

**Returns:**
- `nil`

**Example:**
```lua
local zeke = require('zeke')

-- Cancel all tasks
zeke.cancel_all_tasks()
```

## 🔍 Utilities

### Internal Modules

These modules are available but primarily for internal use:

#### `require('zeke.ui')`

```lua
local ui = require('zeke.ui')

-- UI functions
ui.open_chat()           -- Open chat window
ui.close_chat()          -- Close chat window
ui.toggle_chat()         -- Toggle chat window
ui.focus_chat()          -- Focus chat window
ui.clear_chat()          -- Clear conversation
ui.save_conversation()   -- Save conversation
ui.list_conversations()  -- List conversations
```

#### `require('zeke.workspace')`

```lua
local workspace = require('zeke.workspace')

-- Workspace functions
workspace.setup()                    -- Initialize workspace
workspace.scan_workspace()           -- Scan for files
workspace.add_file_to_context(path)  -- Add file to context
workspace.remove_file_from_context(path) -- Remove from context
workspace.clear_context()            -- Clear context
workspace.get_context_summary()      -- Get context info
workspace.build_context_prompt()     -- Build context for AI
workspace.search_files(query)        -- Search files
workspace.file_picker()              -- Open file picker
```

#### `require('zeke.diff')`

```lua
local diff = require('zeke.diff')

-- Diff functions
diff.show_diff(original, modified, buffer)  -- Show diff view
diff.show_ai_edit_diff(response)           -- Show AI edit diff
diff.preview_file_creation(content, name)  -- Preview file creation
diff.extract_code_blocks(content)          -- Extract code blocks
```

## 📝 Type Definitions

### Configuration Types

```lua
---@class ZekeConfig
---@field default_provider string
---@field default_model string
---@field api_keys table<string, string>
---@field temperature number
---@field max_tokens number
---@field stream boolean
---@field auto_reload boolean
---@field keymaps ZekeKeymaps
---@field server ZekeServerConfig
---@field workspace ZekeWorkspaceConfig
---@field ui ZekeUIConfig

---@class ZekeKeymaps
---@field chat string|false
---@field edit string|false
---@field explain string|false
---@field create string|false
---@field analyze string|false
---@field toggle_chat string|false
---@field models string|false
---@field tasks string|false

---@class ZekeServerConfig
---@field host string
---@field port number
---@field auto_start boolean

---@class ZekeWorkspaceConfig
---@field auto_scan boolean
---@field max_file_size number
---@field include_patterns string[]
---@field exclude_patterns string[]

---@class ZekeUIConfig
---@field chat ZekeWindowConfig
---@field diff ZekeWindowConfig
---@field preview ZekeWindowConfig

---@class ZekeWindowConfig
---@field width number
---@field height number
---@field border string
---@field title string
---@field title_pos string
```

### Function Signatures

```lua
---@class ZekeAPI
local zeke = {}

---@param message? string
---@return nil
function zeke.chat(message) end

---@param instruction? string
---@return nil
function zeke.edit(instruction) end

---@param code? string
---@return nil
function zeke.explain(code) end

---@param description? string
---@return nil
function zeke.create(description) end

---@param analysis_type? string
---@param code? string
---@return nil
function zeke.analyze(analysis_type, code) end

---@return nil
function zeke.toggle_chat() end

---@param filepath? string
---@return nil
function zeke.add_file_to_context(filepath) end

---@return nil
function zeke.add_current_file_to_context() end

---@return nil
function zeke.add_selection_to_context() end

---@return string
function zeke.show_context() end

---@return nil
function zeke.clear_context() end

---@param provider? string
---@return nil
function zeke.set_provider(provider) end

---@return string[]
function zeke.list_models() end

---@param model? string
---@return nil
function zeke.set_model(model) end

---@return string
function zeke.get_current_model() end

---@param query? string
---@return nil
function zeke.workspace_search(query) end

---@return nil
function zeke.list_tasks() end

---@param task_id? number
---@return nil
function zeke.cancel_task(task_id) end

---@return nil
function zeke.cancel_all_tasks() end
```

## 🔗 Integration Examples

### With Telescope

```lua
-- Integration with telescope.nvim
local function zeke_file_picker()
  require('telescope.builtin').find_files({
    prompt_title = "Add File to Zeke Context",
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', function()
        local selection = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(prompt_bufnr)
        require('zeke').add_file_to_context(selection.path)
        vim.notify('Added ' .. selection.filename .. ' to context')
      end)
      return true
    end,
  })
end

vim.keymap.set('n', '<leader>zf', zeke_file_picker)
```

### With LSP

```lua
-- Use Zeke to explain LSP diagnostics
vim.keymap.set('n', '<leader>zd', function()
  local diagnostics = vim.diagnostic.get(0)  -- Current buffer
  if #diagnostics == 0 then
    vim.notify('No diagnostics found')
    return
  end

  local messages = {}
  for _, diag in ipairs(diagnostics) do
    table.insert(messages, string.format('Line %d: %s', diag.lnum + 1, diag.message))
  end

  local diagnostic_text = table.concat(messages, '\n')
  require('zeke').chat('Explain these diagnostics and how to fix them:\n' .. diagnostic_text)
end, { desc = 'Explain LSP diagnostics with Zeke' })
```

### With Git

```lua
-- Explain git diff with Zeke
vim.keymap.set('n', '<leader>zgd', function()
  local diff = vim.fn.system('git diff HEAD~1')
  if diff == '' then
    vim.notify('No changes found')
    return
  end

  require('zeke').chat('Explain this git diff:\n```diff\n' .. diff .. '\n```')
end, { desc = 'Explain git diff with Zeke' })
```

### Custom Commands

```lua
-- Create custom commands that combine multiple operations
vim.api.nvim_create_user_command('ZekeReview', function()
  -- Add current file and run security analysis
  require('zeke').add_current_file_to_context()
  require('zeke').analyze('security')
end, { desc = 'Review current file with Zeke' })

vim.api.nvim_create_user_command('ZekeProject', function()
  -- Add project files and ask for overview
  require('zeke').workspace_search('main')
  require('zeke').workspace_search('config')
  require('zeke').chat('Give me an overview of this project structure')
end, { desc = 'Get project overview with Zeke' })
```

---

**Need more API documentation?** Check the [source code](https://github.com/ghostkellz/zeke.nvim) or ask in [Discussions](https://github.com/ghostkellz/zeke.nvim/discussions)!