--[[
  zeke.nvim Model Management

  Comprehensive model cycling and provider awareness system.
  Supports:
  - Direct API calls (OpenAI, Claude, xAI, Google, Azure)
  - GitHub Copilot Pro (GPT-5 Codex, Grok, Sonnet via credits)
  - Ollama (localhost or remote IP)
  - Model cycling with Tab key
--]]

local M = {}
local cli = require('zeke.cli')
local logger = require('zeke.logger')

-- Model registry with metadata
M.models = {
  -- Anthropic Claude (Direct API)
  {
    id = "claude-opus-4-1",
    name = "Claude Opus 4.1",
    provider = "claude",
    source = "api",
    context_window = 200000,
    supports_vision = true,
    icon = "󰚩",
    description = "Most capable, best for complex tasks",
  },
  {
    id = "claude-sonnet-4-5",
    name = "Claude Sonnet 4.5",
    provider = "claude",
    source = "api",
    context_window = 200000,
    supports_vision = true,
    icon = "󰚩",
    description = "Balanced, best price/performance",
  },

  -- OpenAI (Direct API)
  {
    id = "gpt-4-turbo",
    name = "GPT-4 Turbo",
    provider = "openai",
    source = "api",
    context_window = 128000,
    supports_vision = true,
    icon = "",
    description = "Latest GPT-4, strong reasoning",
  },
  {
    id = "gpt-4o",
    name = "GPT-4o",
    provider = "openai",
    source = "api",
    context_window = 128000,
    supports_vision = true,
    icon = "",
    description = "Multimodal, fast",
  },

  -- xAI Grok
  {
    id = "grok-beta",
    name = "Grok Beta",
    provider = "xai",
    source = "api",
    context_window = 131072,
    icon = "󱙺",
    description = "xAI's conversational model",
  },
  {
    id = "grok-vision-beta",
    name = "Grok Vision",
    provider = "xai",
    source = "api",
    context_window = 8192,
    supports_vision = true,
    icon = "󱙺",
    description = "Grok with vision capabilities",
  },

  -- Google Gemini
  {
    id = "gemini-pro",
    name = "Gemini Pro",
    provider = "google",
    source = "api",
    context_window = 32768,
    icon = "󰊤",
    description = "Google's large model",
  },
  {
    id = "gemini-1.5-flash",
    name = "Gemini 1.5 Flash",
    provider = "google",
    source = "api",
    context_window = 1000000,
    icon = "󰊤",
    description = "Fast, long context",
  },

  -- GitHub Copilot Pro (via GitHub credits)
  {
    id = "copilot-gpt-5-codex",
    name = "GPT-5 Codex Preview",
    provider = "copilot",
    source = "github_credits",
    context_window = 128000,
    icon = "",
    description = "Copilot Pro: GPT-5 preview",
    requires_copilot_pro = true,
  },
  {
    id = "copilot-grok-fast",
    name = "Grok Code Fast 1",
    provider = "copilot",
    source = "github_credits",
    context_window = 32768,
    icon = "󱙺",
    description = "Copilot Pro: Grok fast mode",
    requires_copilot_pro = true,
  },
  {
    id = "copilot-sonnet-4.5",
    name = "Claude Sonnet 4.5 (Pro)",
    provider = "copilot",
    source = "github_credits",
    context_window = 200000,
    icon = "󰚩",
    description = "Copilot Pro: Sonnet via credits",
    requires_copilot_pro = true,
  },
  {
    id = "copilot-gpt-5",
    name = "GPT-5",
    provider = "copilot",
    source = "github_credits",
    context_window = 128000,
    icon = "",
    description = "Copilot Pro: Full GPT-5",
    requires_copilot_pro = true,
  },

  -- LiteLLM (Unified Proxy)
  {
    id = "litellm",
    name = "LiteLLM Proxy",
    provider = "litellm",
    source = "proxy",
    context_window = 128000,  -- Depends on underlying model
    icon = "󰿘",
    description = "Unified AI proxy server",
    configurable_host = true,
    default_host = "http://localhost:4000",
  },

  -- Ollama (Local/Remote)
  {
    id = "qwen2.5-coder:7b",
    name = "Qwen2.5 Coder 7B",
    provider = "ollama",
    source = "local",
    context_window = 32768,
    icon = "󰒋",
    description = "Fast local coding model",
    configurable_host = true,
    default_host = "http://localhost:11434",
  },
  {
    id = "codellama:13b",
    name = "Code Llama 13B",
    provider = "ollama",
    source = "local",
    context_window = 16384,
    icon = "󰒋",
    description = "Meta's code model",
    configurable_host = true,
  },
  {
    id = "deepseek-coder:6.7b",
    name = "DeepSeek Coder",
    provider = "ollama",
    source = "local",
    context_window = 16384,
    icon = "󰒋",
    description = "DeepSeek's coding model",
    configurable_host = true,
  },
  {
    id = "llama3.2:3b",
    name = "Llama 3.2 3B",
    provider = "ollama",
    source = "local",
    context_window = 128000,
    icon = "󰒋",
    description = "Fast, general purpose",
    configurable_host = true,
    default_host = "http://localhost:11434",
  },

  -- Custom hosts can be added dynamically
  -- See config.lua for ollama_hosts and litellm_hosts

  -- Aliases
  {
    id = "smart",
    name = "Smart (Best Available)",
    provider = "auto",
    source = "alias",
    icon = "󰚩",
    description = "Auto-selects best model",
    resolves_to = "claude-opus-4-1",
  },
  {
    id = "fast",
    name = "Fast (Local)",
    provider = "auto",
    source = "alias",
    icon = "󰒋",
    description = "Fastest local model",
    resolves_to = "qwen2.5-coder:7b",
  },
  {
    id = "balanced",
    name = "Balanced",
    provider = "auto",
    source = "alias",
    icon = "󰚩",
    description = "Best price/performance",
    resolves_to = "claude-sonnet-4-5",
  },
}

-- Current model index for cycling
M.current_index = 1

-- Get model by ID
function M.get_model(id)
  for _, model in ipairs(M.models) do
    if model.id == id then
      return model
    end
  end
  return nil
end

-- Get all models for a provider
function M.get_models_by_provider(provider)
  local result = {}
  for _, model in ipairs(M.models) do
    if model.provider == provider or provider == "all" then
      table.insert(result, model)
    end
  end
  return result
end

-- Get all models by source (api, github_credits, local)
function M.get_models_by_source(source)
  local result = {}
  for _, model in ipairs(M.models) do
    if model.source == source then
      table.insert(result, model)
    end
  end
  return result
end

-- Filter models (for UI picker)
function M.filter_models(opts)
  opts = opts or {}
  local result = {}

  for _, model in ipairs(M.models) do
    local include = true

    -- Filter by provider
    if opts.provider and model.provider ~= opts.provider then
      include = false
    end

    -- Filter by source
    if opts.source and model.source ~= opts.source then
      include = false
    end

    -- Filter out aliases if requested
    if opts.no_aliases and model.source == "alias" then
      include = false
    end

    -- Filter by Copilot Pro requirement
    if opts.copilot_pro_only and not model.requires_copilot_pro then
      include = false
    end

    if include then
      table.insert(result, model)
    end
  end

  return result
end

-- Cycle to next model
function M.cycle_next()
  M.current_index = M.current_index + 1
  if M.current_index > #M.models then
    M.current_index = 1
  end

  local model = M.models[M.current_index]
  logger.info("models", "Cycling to: " .. model.name)

  -- Set the model via CLI
  cli.model_set(model.id)

  return model
end

-- Cycle to previous model
function M.cycle_prev()
  M.current_index = M.current_index - 1
  if M.current_index < 1 then
    M.current_index = #M.models
  end

  local model = M.models[M.current_index]
  logger.info("models", "Cycling to: " .. model.name)

  cli.model_set(model.id)

  return model
end

-- Set current model by ID
function M.set_model(id)
  local model = M.get_model(id)
  if not model then
    logger.error("models", "Model not found: " .. id)
    return nil
  end

  -- Update current index
  for i, m in ipairs(M.models) do
    if m.id == id then
      M.current_index = i
      break
    end
  end

  logger.info("models", "Setting model: " .. model.name)
  cli.model_set(id)

  return model
end

-- Get current model
function M.get_current()
  return M.models[M.current_index]
end

-- Show model picker UI
function M.show_picker(opts)
  opts = opts or {}

  local models = M.filter_models(opts)

  if #models == 0 then
    vim.notify("No models available", vim.log.levels.WARN)
    return
  end

  -- Format model list for vim.ui.select
  local formatted = {}
  for i, model in ipairs(models) do
    local prefix = (i == M.current_index) and "→ " or "  "
    local copilot_badge = model.requires_copilot_pro and " [Pro]" or ""
    local source_badge = ""
    if model.source == "api" then
      source_badge = " [API]"
    elseif model.source == "github_credits" then
      source_badge = " [GitHub]"
    elseif model.source == "local" then
      source_badge = " [Local]"
    end

    table.insert(formatted, string.format(
      "%s%s %s%s%s\n   %s",
      prefix,
      model.icon or "",
      model.name,
      copilot_badge,
      source_badge,
      model.description
    ))
  end

  vim.ui.select(formatted, {
    prompt = "Select Model:",
    format_item = function(item)
      return item
    end,
  }, function(_, idx)
    if idx then
      M.set_model(models[idx].id)
      vim.notify("Model: " .. models[idx].name, vim.log.levels.INFO)
    end
  end)
end

-- Get model info as string
function M.model_info(model)
  model = model or M.get_current()
  if not model then
    return "No model selected"
  end

  local lines = {
    string.format("%s %s", model.icon or "", model.name),
    "",
    "Provider: " .. model.provider,
    "Source: " .. model.source,
    "Context: " .. (model.context_window / 1000) .. "k tokens",
  }

  if model.supports_vision then
    table.insert(lines, "Vision: ✓")
  end

  if model.requires_copilot_pro then
    table.insert(lines, "Requires: GitHub Copilot Pro")
  end

  if model.configurable_host then
    table.insert(lines, "Host: Configurable (Ollama)")
  end

  table.insert(lines, "")
  table.insert(lines, model.description)

  return table.concat(lines, "\n")
end

return M
