--[[
  zeke.nvim - Your Claude Code Alternative

  Enhanced with:
  - :ZekeCode - Main AI agent interface
  - Model cycling (Tab/S-Tab)
  - Multiple Ollama hosts
  - LiteLLM support
  - GitHub Copilot Pro integration
--]]

local M = {}

local config = require('zeke.config')
local commands = require('zeke.commands')
local agent = require('zeke.agent')
local models = require('zeke.models')
local logger = require('zeke.logger')
local selection = require('zeke.selection')
local diff = require('zeke.diff')
local integrations = require('zeke.integrations')
local ghostlang = require('zeke.ghostlang')
local cli = require('zeke.cli')
local completion = require('zeke.completion')
local chat_panel = require('zeke.chat.panel')
local lsp = require('zeke.lsp')

function M.setup(opts)
  opts = opts or {}
  config.setup(opts)

  -- Get merged config
  local cfg = config.options

  -- Setup logger
  logger.setup(cfg.logger or {})

  -- Setup diff module
  diff.setup(cfg.diff or {})

  -- Setup selection tracking if enabled
  if cfg.track_selection ~= false then
    selection.enable(cfg.selection or {})
  end

  -- Setup integrations
  integrations.setup()

  -- Setup ghostlang integration
  ghostlang.setup(cfg.ghostlang or {})
  ghostlang.setup_zeke_integration()

  -- Setup inline completions
  if cfg.completion ~= false then
    completion.setup(cfg.completion or {})
  end

  -- Health check
  local health = cli.health_check()
  if not health.installed then
    vim.notify(
      "Zeke CLI not found. Install from: https://github.com/ghostkellz/zeke",
      vim.log.levels.WARN
    )
  elseif not health.working then
    vim.notify(
      "Zeke CLI found but not working: " .. (health.error or "unknown error"),
      vim.log.levels.WARN
    )
  else
    logger.info("init", "Zeke CLI ready: " .. (health.version or "unknown"))
  end

  -- Create lock file for Zeke CLI discovery (if enabled)
  if opts.create_lockfile ~= false then
    local lockfile = require('zeke.lockfile')
    lockfile.create(0)  -- No port needed for CLI mode
  end

  -- =============================================================================
  -- User Commands
  -- =============================================================================

  -- Main agent interface
  vim.api.nvim_create_user_command('ZekeCode', function()
    agent.toggle()
  end, { desc = 'Open ZekeCode AI Agent Interface' })

  vim.api.nvim_create_user_command('ZekeCodeClose', function()
    agent.close()
  end, { desc = 'Close ZekeCode interface' })

  vim.api.nvim_create_user_command('ZekeCodeClear', function()
    agent.clear_chat()
  end, { desc = 'Clear ZekeCode chat history' })

  vim.api.nvim_create_user_command('ZekeCodeSave', function(args)
    agent.save_conversation(args.args ~= '' and args.args or nil)
  end, { nargs = '?', desc = 'Save ZekeCode conversation' })

  -- Chat panel
  vim.api.nvim_create_user_command('ZekeChatPanel', function()
    chat_panel.toggle()
  end, { desc = 'Toggle Zeke chat panel' })

  vim.api.nvim_create_user_command('ZekeChatOpen', function()
    chat_panel.open()
  end, { desc = 'Open Zeke chat panel' })

  vim.api.nvim_create_user_command('ZekeChatClose', function()
    chat_panel.close()
  end, { desc = 'Close Zeke chat panel' })

  vim.api.nvim_create_user_command('ZekeChatClear', function()
    chat_panel.clear()
  end, { desc = 'Clear chat history' })

  -- Original commands (still available)
  vim.api.nvim_create_user_command('ZekeChat', function(args)
    commands.chat(args.args)
  end, { nargs = '?', desc = 'Chat with Zeke AI' })

  vim.api.nvim_create_user_command('ZekeEdit', function(args)
    commands.edit_buffer(args.args)
  end, { nargs = '?', desc = 'Edit current buffer with Zeke' })

  vim.api.nvim_create_user_command('ZekeExplain', function()
    commands.explain()
  end, { desc = 'Explain current buffer with Zeke' })

  vim.api.nvim_create_user_command('ZekeCreate', function(args)
    commands.create_file(args.args)
  end, { nargs = '?', desc = 'Create file with Zeke' })

  vim.api.nvim_create_user_command('ZekeAnalyze', function(args)
    local analysis_type = args.args or 'quality'
    commands.analyze(analysis_type)
  end, { nargs = '?', desc = 'Analyze code with Zeke' })

  -- LSP integration commands
  vim.api.nvim_create_user_command('ZekeFix', function()
    lsp.context.fix_diagnostic_at_cursor()
  end, { desc = 'Fix diagnostic at cursor with AI' })

  vim.api.nvim_create_user_command('ZekeExplainDiagnostic', function()
    lsp.context.explain_diagnostic_at_cursor()
  end, { desc = 'Explain diagnostic at cursor' })

  -- Model management
  vim.api.nvim_create_user_command('ZekeModels', function()
    models.show_picker()
  end, { desc = 'Show model picker' })

  vim.api.nvim_create_user_command('ZekeModelInfo', function()
    local current = models.get_current()
    local info = models.model_info(current)
    vim.notify(info, vim.log.levels.INFO)
  end, { desc = 'Show current model info' })

  vim.api.nvim_create_user_command('ZekeModelSet', function(args)
    if args.args == '' then
      models.show_picker()
    else
      models.set_model(args.args)
    end
  end, { nargs = '?', desc = 'Set AI model' })

  vim.api.nvim_create_user_command('ZekeModelNext', function()
    local model = models.cycle_next()
    vim.notify(string.format("%s %s", model.icon, model.name), vim.log.levels.INFO)
  end, { desc = 'Cycle to next model' })

  vim.api.nvim_create_user_command('ZekeModelPrev', function()
    local model = models.cycle_prev()
    vim.notify(string.format("%s %s", model.icon, model.name), vim.log.levels.INFO)
  end, { desc = 'Cycle to previous model' })

  -- Provider management
  vim.api.nvim_create_user_command('ZekeProviders', function()
    commands.list_providers()
  end, { desc = 'List available providers' })

  vim.api.nvim_create_user_command('ZekeProviderSet', function(args)
    commands.set_provider(args.args)
  end, { nargs = '?', desc = 'Set AI provider' })

  vim.api.nvim_create_user_command('ZekeProviderStatus', function()
    commands.provider_status()
  end, { desc = 'Show provider status' })

  -- Ollama host management
  vim.api.nvim_create_user_command('ZekeOllamaHosts', function()
    local hosts = config.list_ollama_hosts()
    local lines = { "Configured Ollama Hosts:", "" }
    for _, host in ipairs(hosts) do
      table.insert(lines, string.format("  %s: %s", host.name, host.url))
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, { desc = 'List Ollama hosts' })

  -- LiteLLM host management
  vim.api.nvim_create_user_command('ZekeLiteLLMHosts', function()
    local hosts = config.list_litellm_hosts()
    local lines = { "Configured LiteLLM Hosts:", "" }
    for _, host in ipairs(hosts) do
      table.insert(lines, string.format("  %s: %s", host.name, host.url))
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, { desc = 'List LiteLLM hosts' })

  -- Health check
  vim.api.nvim_create_user_command('ZekeHealth', function()
    local health = cli.health_check()
    local status_lines = {
      "Zeke CLI Health Check",
      "",
      "Installed: " .. (health.installed and "✓" or "✗"),
    }

    if health.installed then
      table.insert(status_lines, "Path: " .. health.path)
      table.insert(status_lines, "Working: " .. (health.working and "✓" or "✗"))
      if health.version then
        table.insert(status_lines, "Version: " .. health.version)
      end
    end

    if health.error then
      table.insert(status_lines, "")
      table.insert(status_lines, "Error: " .. health.error)
    end

    vim.notify(table.concat(status_lines, "\n"), vim.log.levels.INFO)
  end, { desc = 'Check Zeke CLI health' })

  -- =============================================================================
  -- Keymaps
  -- =============================================================================

  if cfg.keymaps.enabled then
    local km = cfg.keymaps

    -- Main commands
    if km.code then
      vim.keymap.set('n', km.code, ':ZekeCode<CR>', { desc = 'Open ZekeCode Agent', silent = true })
    end

    if km.chat then
      vim.keymap.set('n', km.chat, function()
        vim.ui.input({ prompt = 'Chat: ' }, function(input)
          if input then commands.chat(input) end
        end)
      end, { desc = 'Quick chat with Zeke', silent = true })
    end

    if km.explain then
      vim.keymap.set('n', km.explain, ':ZekeExplain<CR>', { desc = 'Explain code', silent = true })
    end

    if km.edit then
      vim.keymap.set('n', km.edit, function()
        vim.ui.input({ prompt = 'Edit instruction: ' }, function(input)
          if input then commands.edit_buffer(input) end
        end)
      end, { desc = 'Edit with AI', silent = true })
    end

    -- Model management
    if km.model_picker then
      vim.keymap.set('n', km.model_picker, ':ZekeModels<CR>', { desc = 'Model picker', silent = true })
    end

    if km.model_next then
      vim.keymap.set('n', km.model_next, ':ZekeModelNext<CR>', { desc = 'Next model', silent = true })
    end

    if km.model_prev then
      vim.keymap.set('n', km.model_prev, ':ZekeModelPrev<CR>', { desc = 'Previous model', silent = true })
    end

    -- Chat panel
    if km.chat_panel then
      vim.keymap.set('n', km.chat_panel, ':ZekeChatPanel<CR>', { desc = 'Toggle chat panel', silent = true })
    end

    -- LSP integration
    if km.fix_diagnostic then
      vim.keymap.set('n', km.fix_diagnostic, ':ZekeFix<CR>', { desc = 'Fix diagnostic with AI', silent = true })
    end

    if km.explain_diagnostic then
      vim.keymap.set('n', km.explain_diagnostic, ':ZekeExplainDiagnostic<CR>', { desc = 'Explain diagnostic', silent = true })
    end

    -- AI assistance shortcuts (similar to Copilot)
    vim.keymap.set('n', '<leader>aa', function()
      vim.ui.input({ prompt = 'Ask AI: ' }, function(input)
        if input then
          chat_panel.open()
          chat_panel.send_message(input)
        end
      end)
    end, { desc = 'Ask AI', silent = true })

    vim.keymap.set('n', '<leader>af', ':ZekeFix<CR>', { desc = 'AI: Fix diagnostic', silent = true })
    vim.keymap.set('n', '<leader>ae', ':ZekeEdit<CR>', { desc = 'AI: Edit selection', silent = true })
    vim.keymap.set('v', '<leader>ae', function()
      -- Get visual selection
      local start_pos = vim.fn.getpos("'<")
      local end_pos = vim.fn.getpos("'>")
      local lines = vim.fn.getline(start_pos[2], end_pos[2])

      vim.ui.input({ prompt = 'Edit instruction: ' }, function(input)
        if input then
          local context = table.concat(lines, '\n')
          local prompt = string.format("Edit the following code:\n\n```\n%s\n```\n\nInstruction: %s", context, input)
          chat_panel.open()
          chat_panel.send_message(prompt)
        end
      end)
    end, { desc = 'AI: Edit selection', silent = true })

    vim.keymap.set('n', '<leader>ax', ':ZekeExplain<CR>', { desc = 'AI: Explain code', silent = true })
    vim.keymap.set('n', '<leader>ac', ':ZekeChatPanel<CR>', { desc = 'AI: Toggle chat', silent = true })
    vim.keymap.set('n', '<leader>at', function() completion.inline.toggle() end, { desc = 'AI: Toggle completions', silent = true })

    if km.model_info then
      vim.keymap.set('n', km.model_info, ':ZekeModelInfo<CR>', { desc = 'Model info', silent = true })
    end

    -- Quick switches
    if km.quick_smart then
      vim.keymap.set('n', km.quick_smart, function()
        models.set_model('smart')
        vim.notify("Model: Smart", vim.log.levels.INFO)
      end, { desc = 'Switch to Smart', silent = true })
    end

    if km.quick_fast then
      vim.keymap.set('n', km.quick_fast, function()
        models.set_model('fast')
        vim.notify("Model: Fast", vim.log.levels.INFO)
      end, { desc = 'Switch to Fast', silent = true })
    end

    if km.quick_local then
      vim.keymap.set('n', km.quick_local, function()
        models.set_model('qwen2.5-coder:7b')
        vim.notify("Model: Qwen2.5 Coder (Ollama)", vim.log.levels.INFO)
      end, { desc = 'Switch to Local Ollama', silent = true })
    end
  end

  logger.info("init", "zeke.nvim initialized successfully")
end

-- Export submodules for direct access
M.commands = commands
M.agent = agent
M.models = models
M.cli = cli
M.config = config
M.logger = logger

return M
