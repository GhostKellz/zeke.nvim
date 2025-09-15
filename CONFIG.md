# ⚙️ Configuration Reference

Complete configuration reference for **zeke.nvim** with examples and explanations.

## 📖 Table of Contents

- [🎯 Quick Configuration](#-quick-configuration)
- [🔧 Full Configuration](#-full-configuration)
- [🤖 Provider Configuration](#-provider-configuration)
- [🎨 UI Customization](#-ui-customization)
- [⌨️ Keymap Configuration](#️-keymap-configuration)
- [📁 Workspace Settings](#-workspace-settings)
- [🔄 Runtime Configuration](#-runtime-configuration)
- [📝 Configuration Examples](#-configuration-examples)

## 🎯 Quick Configuration

### Minimal Setup

```lua
require('zeke').setup({
  default_provider = 'openai',
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
  },
})
```

### Recommended Setup

```lua
require('zeke').setup({
  -- Core settings
  default_provider = 'openai',
  default_model = 'gpt-4',

  -- API keys from environment
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
    claude = vim.env.ANTHROPIC_API_KEY,
  },

  -- UI settings
  keymaps = {
    chat = '<leader>zc',
    toggle_chat = '<leader>zt',
    edit = '<leader>ze',
  },
})
```

## 🔧 Full Configuration

### Complete Configuration Schema

```lua
require('zeke').setup({
  -- Provider Settings
  default_provider = 'openai',     -- 'openai' | 'claude' | 'copilot' | 'ollama'
  default_model = 'gpt-4',         -- Model name (provider-specific)

  -- API Keys
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
    claude = vim.env.ANTHROPIC_API_KEY,
    copilot = vim.env.GITHUB_TOKEN,
  },

  -- Generation Parameters
  temperature = 0.7,               -- 0.0 to 2.0, creativity level
  max_tokens = 2048,              -- Maximum response length
  stream = false,                 -- Enable streaming responses

  -- UI Settings
  auto_reload = true,             -- Auto-reload files after edits

  -- Keymaps
  keymaps = {
    -- Core AI functions
    chat = '<leader>zc',          -- Chat with AI
    edit = '<leader>ze',          -- Edit buffer
    explain = '<leader>zx',       -- Explain code
    create = '<leader>zn',        -- Create file
    analyze = '<leader>za',       -- Analyze code

    -- UI functions
    toggle_chat = '<leader>zt',   -- Toggle chat window
    chat_stream = '<leader>zs',   -- Streaming chat

    -- Context management
    add_file = '<leader>zf',      -- Add file to context
    add_current = '<leader>zac',  -- Add current file
    add_selection = '<leader>zas', -- Add selection
    show_context = '<leader>zsc', -- Show context
    clear_context = '<leader>zcc', -- Clear context

    -- Provider management
    models = '<leader>zm',        -- List models
    tasks = '<leader>zt',         -- List tasks

    -- Set to false to disable specific keymaps
    create = false,               -- Disable create keymap
  },

  -- Server Configuration (future use)
  server = {
    host = '127.0.0.1',          -- Server host
    port = 7777,                 -- Server port
    auto_start = true,           -- Auto-start server
  },

  -- Workspace Settings
  workspace = {
    auto_scan = true,            -- Auto-scan workspace on startup
    max_file_size = 1048576,     -- Max file size (1MB)
    include_patterns = {         -- File patterns to include
      '*.lua', '*.rs', '*.py', '*.js', '*.ts',
      '*.go', '*.c', '*.cpp', '*.java', '*.kt',
      '*.rb', '*.php', '*.cs', '*.swift',
    },
    exclude_patterns = {         -- Patterns to exclude
      '*/node_modules/*', '*/.git/*', '*/target/*',
      '*/build/*', '*/dist/*', '*/.vscode/*',
      '*/__pycache__/*', '*.pyc', '*.class',
    },
  },

  -- UI Customization
  ui = {
    -- Chat window settings
    chat = {
      width = 0.8,               -- 80% of screen width
      height = 0.8,              -- 80% of screen height
      border = 'rounded',        -- 'single' | 'double' | 'rounded' | 'solid' | 'shadow'
      title = ' Zeke Chat ',     -- Window title
      title_pos = 'center',      -- 'left' | 'center' | 'right'
    },

    -- Diff window settings
    diff = {
      width = 0.9,               -- 90% of screen width
      height = 0.8,              -- 80% of screen height
      border = 'rounded',
      title = ' Code Diff ',
    },

    -- Preview window settings
    preview = {
      width = 0.8,
      height = 0.8,
      border = 'rounded',
    },
  },

  -- Logging and Debug
  debug = false,                 -- Enable debug mode
  log_level = 'info',           -- 'debug' | 'info' | 'warn' | 'error'
  log_file = nil,               -- Log file path (nil = no file logging)
})
```

## 🤖 Provider Configuration

### OpenAI Configuration

```lua
require('zeke').setup({
  default_provider = 'openai',
  default_model = 'gpt-4',
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
  },

  -- OpenAI-specific settings
  temperature = 0.7,             -- Creativity (0.0 = deterministic, 2.0 = very creative)
  max_tokens = 4096,             -- Max response length
})

-- Available OpenAI models
local openai_models = {
  'gpt-4',                       -- Best quality, slower
  'gpt-4-turbo',                 -- Fast GPT-4
  'gpt-3.5-turbo',              -- Fast, good quality
  'gpt-3.5-turbo-16k',          -- Longer context
}
```

### Claude Configuration

```lua
require('zeke').setup({
  default_provider = 'claude',
  default_model = 'claude-3-5-sonnet-20241022',
  api_keys = {
    claude = vim.env.ANTHROPIC_API_KEY,
  },

  -- Claude works well with higher token limits
  max_tokens = 4096,
  temperature = 0.7,
})

-- Available Claude models
local claude_models = {
  'claude-3-5-sonnet-20241022',  -- Latest, best for coding
  'claude-3-5-haiku-20241022',   -- Fast, cost-effective
  'claude-3-opus-20240229',      -- Most capable, expensive
  'claude-3-sonnet-20240229',    -- Balanced
}
```

### Ollama Configuration

```lua
require('zeke').setup({
  default_provider = 'ollama',
  default_model = 'codellama',   -- Great for coding tasks

  -- No API key needed for local models

  -- Ollama-specific settings
  temperature = 0.3,             -- Lower for code generation
  max_tokens = 2048,
})

-- Set custom Ollama host if needed
vim.env.OLLAMA_HOST = "http://192.168.1.100:11434"

-- Popular Ollama models for coding
local ollama_models = {
  'codellama',                   -- Best for coding
  'codellama:13b',              -- Larger, better quality
  'llama2',                     -- General purpose
  'mistral',                    -- Fast, good quality
  'mixtral',                    -- Very capable
}
```

### Multi-Provider Setup

```lua
require('zeke').setup({
  -- Start with OpenAI
  default_provider = 'openai',
  default_model = 'gpt-4',

  -- Configure all providers
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
    claude = vim.env.ANTHROPIC_API_KEY,
    copilot = vim.env.GITHUB_TOKEN,
  },
})

-- Create keymaps to switch providers quickly
vim.keymap.set('n', '<leader>zo', function()
  require('zeke').set_provider('openai')
  vim.notify('Switched to OpenAI')
end, { desc = 'Switch to OpenAI' })

vim.keymap.set('n', '<leader>zl', function()
  require('zeke').set_provider('ollama')
  vim.notify('Switched to Ollama (local)')
end, { desc = 'Switch to Ollama' })
```

## 🎨 UI Customization

### Chat Window Customization

```lua
require('zeke').setup({
  ui = {
    chat = {
      -- Size and position
      width = 0.9,               -- 90% of screen width
      height = 0.85,             -- 85% of screen height

      -- Styling
      border = 'double',         -- Border style
      title = ' 🤖 Zeke Assistant ',
      title_pos = 'center',

      -- Colors (if supported by your colorscheme)
      highlight = 'Normal',      -- Window highlight group
      border_highlight = 'FloatBorder',
    },

    -- Diff view customization
    diff = {
      width = 0.95,
      height = 0.9,
      border = 'rounded',
      title = ' 📝 Code Changes ',
    },
  },
})
```

### Custom Border Styles

```lua
-- Custom ASCII border
require('zeke').setup({
  ui = {
    chat = {
      border = {
        '╭', '─', '╮',
        '│',      '│',
        '╰', '─', '╯'
      },
    },
  },
})

-- No border
require('zeke').setup({
  ui = {
    chat = {
      border = 'none',
    },
  },
})
```

### Window Positioning

```lua
-- Custom window positioning function
local function custom_chat_config()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  return {
    width = width,
    height = height,
    row = 2,                     -- Fixed position from top
    col = math.floor((vim.o.columns - width) / 2), -- Centered horizontally
  }
end

require('zeke').setup({
  ui = {
    chat = custom_chat_config(),
  },
})
```

## ⌨️ Keymap Configuration

### Default Keymaps

```lua
-- These are the default keymaps
require('zeke').setup({
  keymaps = {
    -- Core AI functions
    chat = '<leader>zc',          -- Chat with AI
    edit = '<leader>ze',          -- Edit buffer
    explain = '<leader>zx',       -- Explain code
    create = '<leader>zn',        -- Create new file
    analyze = '<leader>za',       -- Analyze code

    -- UI functions
    toggle_chat = '<leader>zt',   -- Toggle chat window
    chat_stream = '<leader>zs',   -- Streaming chat

    -- Management
    models = '<leader>zm',        -- List models
    tasks = '<leader>ztk',        -- List tasks (avoiding conflict)
  },
})
```

### Custom Keymaps

```lua
require('zeke').setup({
  keymaps = {
    -- Use Ctrl combinations
    chat = '<C-a>c',
    edit = '<C-a>e',
    explain = '<C-a>x',

    -- Use function keys
    toggle_chat = '<F12>',

    -- Use space as leader
    chat = '<Space>ac',
    edit = '<Space>ae',

    -- Disable specific keymaps
    create = false,               -- Don't map create
    analyze = false,              -- Don't map analyze
  },
})
```

### Context Management Keymaps

```lua
require('zeke').setup({
  keymaps = {
    -- Context management
    add_file = '<leader>zaf',     -- Add file via picker
    add_current = '<leader>zac',  -- Add current file
    add_selection = '<leader>zas', -- Add visual selection
    show_context = '<leader>zsc', -- Show context summary
    clear_context = '<leader>zcc', -- Clear all context
    context_files = '<leader>zcf', -- Manage context files

    -- Workspace functions
    search_files = '<leader>zsf', -- Search workspace files
  },
})
```

### Advanced Keymap Patterns

```lua
-- Consistent prefix approach
require('zeke').setup({
  keymaps = {
    -- All Zeke functions under <leader>z
    chat = '<leader>zc',
    edit = '<leader>ze',
    explain = '<leader>zx',
    create = '<leader>zn',
    analyze = '<leader>za',

    -- Context functions under <leader>zc*
    add_current = '<leader>zcc',
    add_file = '<leader>zcf',
    show_context = '<leader>zcs',

    -- UI functions under <leader>zu*
    toggle_chat = '<leader>zuc',

    -- Provider functions under <leader>zp*
    models = '<leader>zpm',
    set_provider = '<leader>zpp',
  },
})

-- Modal approach (different modes)
require('zeke').setup({
  keymaps = {
    -- Normal mode - core functions
    chat = '<leader>c',
    edit = '<leader>e',
    explain = '<leader>x',

    -- Insert mode - quick access
    chat = '<C-g>c',
    edit = '<C-g>e',
  },
})
```

### Buffer-Specific Keymaps

```lua
-- Add keymaps only for specific file types
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'lua', 'rust', 'python', 'javascript', 'typescript' },
  callback = function(args)
    local opts = { buffer = args.buf }

    vim.keymap.set('n', '<leader>ze', function()
      require('zeke').edit()
    end, vim.tbl_extend('force', opts, { desc = 'Zeke edit' }))

    vim.keymap.set('v', '<leader>zs', function()
      require('zeke').add_selection_to_context()
    end, vim.tbl_extend('force', opts, { desc = 'Add selection to context' }))
  end,
})
```

## 📁 Workspace Settings

### File Filtering

```lua
require('zeke').setup({
  workspace = {
    -- Include patterns (what files to index)
    include_patterns = {
      -- Source code
      '*.lua', '*.rs', '*.py', '*.js', '*.ts', '*.jsx', '*.tsx',
      '*.go', '*.c', '*.cpp', '*.h', '*.hpp',
      '*.java', '*.kt', '*.scala',
      '*.rb', '*.php', '*.cs', '*.swift', '*.dart',

      -- Configuration
      '*.toml', '*.yaml', '*.yml', '*.json', '*.xml',
      '*.cfg', '*.ini', '*.conf',

      -- Documentation
      '*.md', '*.txt', '*.rst',

      -- Build files
      'Dockerfile', 'Makefile', 'CMakeLists.txt',
      'package.json', 'Cargo.toml', 'go.mod',
    },

    -- Exclude patterns (what to ignore)
    exclude_patterns = {
      -- Dependencies
      '*/node_modules/*', '*/vendor/*',

      -- Build outputs
      '*/target/*', '*/build/*', '*/dist/*', '*/out/*',

      -- Version control
      '*/.git/*', '*/.svn/*', '*/.hg/*',

      -- IDEs
      '*/.vscode/*', '*/.idea/*',

      -- Temporary files
      '*/__pycache__/*', '*.pyc', '*.class', '*.o', '*.obj',
      '*.exe', '*.dll', '*.so', '*.dylib',

      -- Logs
      '*.log', '*/logs/*',
    },

    -- Performance settings
    max_file_size = 1048576,     -- 1MB max file size
    max_files = 10000,           -- Max files to index
    auto_scan = true,            -- Scan on startup
  },
})
```

### Custom File Detection

```lua
require('zeke').setup({
  workspace = {
    -- Custom include function
    include_file = function(filepath)
      -- Custom logic for including files
      local filename = vim.fn.fnamemodify(filepath, ':t')
      local ext = vim.fn.fnamemodify(filepath, ':e')

      -- Include all code files
      if vim.tbl_contains({'lua', 'rs', 'py', 'js', 'ts'}, ext) then
        return true
      end

      -- Include specific filenames
      if vim.tbl_contains({'Dockerfile', 'Makefile'}, filename) then
        return true
      end

      return false
    end,

    -- Custom exclude function
    exclude_file = function(filepath)
      -- Exclude test files in development
      if vim.env.NODE_ENV == 'development' and filepath:match('%.test%.') then
        return true
      end

      return false
    end,
  },
})
```

## 🔄 Runtime Configuration

### Dynamic Configuration

```lua
-- Change configuration at runtime
local zeke = require('zeke')

-- Switch providers based on task
vim.keymap.set('n', '<leader>zfast', function()
  zeke.set_provider('ollama')
  zeke.set_model('llama2')
  vim.notify('Switched to fast local model')
end)

vim.keymap.set('n', '<leader>zsmart', function()
  zeke.set_provider('claude')
  zeke.set_model('claude-3-5-sonnet-20241022')
  vim.notify('Switched to smart model')
end)

-- Adjust settings based on file type
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'rust',
  callback = function()
    zeke.set_provider('ollama')
    zeke.set_model('codellama')
  end,
})
```

### Context-Aware Configuration

```lua
-- Different settings for different projects
local function setup_for_project()
  local cwd = vim.fn.getcwd()

  if cwd:match('/work/') then
    -- Work projects - use Claude for better quality
    require('zeke').setup({
      default_provider = 'claude',
      default_model = 'claude-3-5-sonnet-20241022',
      temperature = 0.3,  -- More conservative
    })
  elseif cwd:match('/personal/') then
    -- Personal projects - use local models
    require('zeke').setup({
      default_provider = 'ollama',
      default_model = 'codellama',
      temperature = 0.7,  -- More creative
    })
  end
end

-- Run on directory change
vim.api.nvim_create_autocmd('DirChanged', {
  callback = setup_for_project,
})

-- Run on startup
setup_for_project()
```

## 📝 Configuration Examples

### Minimal Configuration

```lua
-- Simplest possible setup
require('zeke').setup({
  default_provider = 'ollama',  -- Free, local
  default_model = 'llama2',
})
```

### Power User Configuration

```lua
require('zeke').setup({
  -- Multiple providers configured
  default_provider = 'claude',
  api_keys = {
    openai = vim.env.OPENAI_API_KEY,
    claude = vim.env.ANTHROPIC_API_KEY,
    copilot = vim.env.GITHUB_TOKEN,
  },

  -- Optimized for coding
  default_model = 'claude-3-5-sonnet-20241022',
  temperature = 0.3,
  max_tokens = 4096,

  -- Custom keymaps
  keymaps = {
    chat = '<C-a>c',
    edit = '<C-a>e',
    explain = '<C-a>x',
    toggle_chat = '<F1>',
    add_current = '<C-a>a',
    show_context = '<C-a>s',
  },

  -- Large workspace handling
  workspace = {
    max_file_size = 2097152,  -- 2MB
    max_files = 50000,
  },

  -- Custom UI
  ui = {
    chat = {
      width = 0.9,
      height = 0.9,
      border = 'double',
      title = ' 🧠 AI Assistant ',
    },
  },
})

-- Additional keymaps for provider switching
local zeke = require('zeke')
vim.keymap.set('n', '<leader>z1', function() zeke.set_provider('ollama') end)
vim.keymap.set('n', '<leader>z2', function() zeke.set_provider('openai') end)
vim.keymap.set('n', '<leader>z3', function() zeke.set_provider('claude') end)
```

### Team Configuration

```lua
-- Configuration for teams (put in shared config)
local team_config = {
  -- Standard provider for consistency
  default_provider = 'openai',
  default_model = 'gpt-4',

  -- Conservative settings
  temperature = 0.5,
  max_tokens = 2048,

  -- Consistent keymaps
  keymaps = {
    chat = '<leader>ac',
    edit = '<leader>ae',
    explain = '<leader>ax',
    toggle_chat = '<leader>at',
  },

  -- Optimized for common file types
  workspace = {
    include_patterns = {
      '*.js', '*.ts', '*.jsx', '*.tsx',  -- React/Node.js
      '*.py',                           -- Python
      '*.go',                          -- Go
      '*.rs',                          -- Rust
      '*.md', '*.json', '*.yaml',      -- Docs/Config
    },
  },
}

require('zeke').setup(team_config)
```

### Performance Configuration

```lua
-- Optimized for large codebases
require('zeke').setup({
  -- Use local model for speed
  default_provider = 'ollama',
  default_model = 'codellama',

  -- Smaller context for speed
  max_tokens = 1024,
  temperature = 0.2,

  -- Minimal UI for performance
  ui = {
    chat = {
      width = 0.6,
      height = 0.6,
      border = 'single',
    },
  },

  -- Strict file filtering
  workspace = {
    max_file_size = 524288,  -- 512KB
    max_files = 1000,
    include_patterns = {
      '*.lua', '*.rs', '*.py',  -- Only main languages
    },
    exclude_patterns = {
      '*/node_modules/*', '*/target/*', '*/.git/*',
      '*/test/*', '*/tests/*',  -- Exclude tests
    },
  },

  -- Disable expensive features
  stream = false,
  auto_reload = false,
})
```

---

**Need help with configuration?** Check the [Documentation](DOCS.md) or ask in [Discussions](https://github.com/ghostkellz/zeke.nvim/discussions)!