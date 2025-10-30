--[[
  Token Estimation and Cost Calculation

  Features:
  - Estimate token count for prompts
  - Calculate API costs
  - Warn about large prompts
  - Track token usage
--]]

local M = {}

local logger = require('zeke.logger')

-- Token usage tracking
M.usage = {
  total_estimated_tokens = 0,
  total_estimated_cost = 0,
  requests_count = 0,
}

-- Cost per 1K tokens (USD) - Updated as of 2024
M.pricing = {
  -- OpenAI
  ["gpt-4-turbo"] = { input = 0.01, output = 0.03 },
  ["gpt-4o"] = { input = 0.005, output = 0.015 },
  ["gpt-4"] = { input = 0.03, output = 0.06 },
  ["gpt-3.5-turbo"] = { input = 0.0005, output = 0.0015 },

  -- Anthropic Claude
  ["claude-opus-4"] = { input = 0.015, output = 0.075 },
  ["claude-sonnet-4"] = { input = 0.003, output = 0.015 },
  ["claude-sonnet-3.5"] = { input = 0.003, output = 0.015 },
  ["claude-haiku-3"] = { input = 0.00025, output = 0.00125 },

  -- Google Gemini
  ["gemini-pro"] = { input = 0.00025, output = 0.00075 },
  ["gemini-1.5-flash"] = { input = 0.000035, output = 0.00014 },
  ["gemini-1.5-pro"] = { input = 0.00125, output = 0.005 },

  -- xAI Grok
  ["grok-beta"] = { input = 0.005, output = 0.015 },

  -- Ollama (local - free)
  ["qwen2.5-coder:7b"] = { input = 0, output = 0 },
  ["deepseek-coder-v2:16b"] = { input = 0, output = 0 },
  ["codellama:13b"] = { input = 0, output = 0 },
  ["llama3:8b"] = { input = 0, output = 0 },
}

---Estimate token count for text (simple approximation)
---@param text string Text to estimate
---@return number Estimated token count
function M.estimate_tokens(text)
  if not text or text == "" then
    return 0
  end

  -- Simple estimation: ~4 characters per token (English)
  -- This is a rough approximation, actual tokenization varies by model
  local char_count = #text

  -- Count words as a better estimate
  local word_count = 0
  for _ in text:gmatch("%S+") do
    word_count = word_count + 1
  end

  -- Average: 1.3 tokens per word, or 1 token per 4 chars
  local word_estimate = math.ceil(word_count * 1.3)
  local char_estimate = math.ceil(char_count / 4)

  -- Use the higher estimate (more conservative)
  return math.max(word_estimate, char_estimate)
end

---Get pricing for a model
---@param model_name string Model name
---@return table|nil Pricing {input, output} per 1K tokens
function M.get_pricing(model_name)
  if not model_name then
    return nil
  end

  -- Try exact match first
  if M.pricing[model_name] then
    return M.pricing[model_name]
  end

  -- Try partial match (e.g., "gpt-4" matches "gpt-4-turbo")
  for price_key, price in pairs(M.pricing) do
    if model_name:match(price_key) or price_key:match(model_name) then
      return price
    end
  end

  -- Default fallback (assume GPT-3.5 pricing)
  return M.pricing["gpt-3.5-turbo"]
end

---Calculate cost for token usage
---@param input_tokens number Input token count
---@param output_tokens number Output token count (estimated)
---@param model_name string Model name
---@return number Cost in USD
---@return table Breakdown {input_cost, output_cost, pricing}
function M.calculate_cost(input_tokens, output_tokens, model_name)
  local pricing = M.get_pricing(model_name)

  if not pricing then
    return 0, { input_cost = 0, output_cost = 0, pricing = nil }
  end

  local input_cost = (input_tokens / 1000) * pricing.input
  local output_cost = (output_tokens / 1000) * pricing.output
  local total_cost = input_cost + output_cost

  return total_cost, {
    input_cost = input_cost,
    output_cost = output_cost,
    pricing = pricing,
  }
end

---Estimate cost for a prompt
---@param prompt string The prompt text
---@param model_name string Model name
---@param estimated_output_tokens number|nil Est. output tokens (default: 500)
---@return table Estimation {input_tokens, output_tokens, cost, breakdown}
function M.estimate_prompt_cost(prompt, model_name, estimated_output_tokens)
  estimated_output_tokens = estimated_output_tokens or 500

  local input_tokens = M.estimate_tokens(prompt)
  local cost, breakdown = M.calculate_cost(input_tokens, estimated_output_tokens, model_name)

  return {
    input_tokens = input_tokens,
    output_tokens = estimated_output_tokens,
    total_tokens = input_tokens + estimated_output_tokens,
    cost = cost,
    breakdown = breakdown,
    model = model_name,
  }
end

---Check if prompt is large and should warn user
---@param prompt string The prompt
---@return boolean Is large
---@return string|nil Warning message
function M.check_large_prompt(prompt)
  local tokens = M.estimate_tokens(prompt)

  -- Define thresholds
  local thresholds = {
    warning = 4000,   -- Warn at 4K tokens
    critical = 8000,  -- Critical warning at 8K
    max = 16000,      -- Block at 16K
  }

  if tokens >= thresholds.max then
    return true, string.format(
      "⚠️  CRITICAL: Prompt is very large (%d tokens)!\n" ..
      "This may fail or be very expensive.\n" ..
      "Consider reducing context or splitting into smaller requests.",
      tokens
    )
  elseif tokens >= thresholds.critical then
    return true, string.format(
      "⚠️  WARNING: Large prompt detected (%d tokens).\n" ..
      "This may be slow and expensive.",
      tokens
    )
  elseif tokens >= thresholds.warning then
    return true, string.format(
      "ℹ️  FYI: Prompt is %d tokens (moderate size).",
      tokens
    )
  end

  return false, nil
end

---Format cost estimate for display
---@param estimate table Cost estimate from estimate_prompt_cost
---@return string Formatted string
function M.format_estimate(estimate)
  local lines = {
    string.format("Model: %s", estimate.model or "unknown"),
    string.format("Input tokens: %d (~%d chars)", estimate.input_tokens, estimate.input_tokens * 4),
    string.format("Estimated output: %d tokens", estimate.output_tokens),
    string.format("Total: %d tokens", estimate.total_tokens),
  }

  if estimate.cost > 0 then
    table.insert(lines, "")
    table.insert(lines, string.format("Estimated cost: $%.4f USD", estimate.cost))

    if estimate.breakdown and estimate.breakdown.pricing then
      table.insert(lines, string.format(
        "  Input: $%.4f ($%.4f per 1K)",
        estimate.breakdown.input_cost,
        estimate.breakdown.pricing.input
      ))
      table.insert(lines, string.format(
        "  Output: $%.4f ($%.4f per 1K)",
        estimate.breakdown.output_cost,
        estimate.breakdown.pricing.output
      ))
    end
  else
    table.insert(lines, "")
    table.insert(lines, "Cost: FREE (local model)")
  end

  return table.concat(lines, "\n")
end

---Show cost estimate before sending
---@param prompt string The prompt
---@param model_name string Model name
---@param callback function Callback (confirmed: boolean)
function M.show_estimate_prompt(prompt, model_name, callback)
  local estimate = M.estimate_prompt_cost(prompt, model_name)
  local formatted = M.format_estimate(estimate)

  -- Check for large prompt warning
  local is_large, warning = M.check_large_prompt(prompt)

  local message = formatted
  if is_large and warning then
    message = warning .. "\n\n" .. formatted
  end

  message = message .. "\n\nSend this request?"

  vim.ui.select(
    { "Yes", "No" },
    {
      prompt = message,
      format_item = function(item) return item end,
    },
    function(choice)
      if callback then
        callback(choice == "Yes", estimate)
      end
    end
  )
end

---Track token usage
---@param input_tokens number Input tokens
---@param output_tokens number Output tokens
---@param cost number Cost in USD
function M.track_usage(input_tokens, output_tokens, cost)
  M.usage.total_estimated_tokens = M.usage.total_estimated_tokens + input_tokens + output_tokens
  M.usage.total_estimated_cost = M.usage.total_estimated_cost + cost
  M.usage.requests_count = M.usage.requests_count + 1

  logger.info('tokens', string.format(
    'Usage tracked: %d input + %d output tokens, $%.4f',
    input_tokens,
    output_tokens,
    cost
  ))
end

---Get usage statistics
---@return table Statistics
function M.get_usage_stats()
  return {
    total_tokens = M.usage.total_estimated_tokens,
    total_cost = M.usage.total_estimated_cost,
    requests = M.usage.requests_count,
    avg_tokens_per_request = M.usage.requests_count > 0 and
      (M.usage.total_estimated_tokens / M.usage.requests_count) or 0,
    avg_cost_per_request = M.usage.requests_count > 0 and
      (M.usage.total_estimated_cost / M.usage.requests_count) or 0,
  }
end

---Format usage statistics
---@return string Formatted stats
function M.format_usage_stats()
  local stats = M.get_usage_stats()

  local lines = {
    "=== Token Usage Statistics ===",
    "",
    string.format("Total requests: %d", stats.requests),
    string.format("Total tokens: %d", stats.total_tokens),
    string.format("Total estimated cost: $%.4f USD", stats.total_cost),
    "",
    string.format("Avg tokens/request: %.0f", stats.avg_tokens_per_request),
    string.format("Avg cost/request: $%.4f", stats.avg_cost_per_request),
  }

  return table.concat(lines, "\n")
end

---Reset usage statistics
function M.reset_usage()
  M.usage = {
    total_estimated_tokens = 0,
    total_estimated_cost = 0,
    requests_count = 0,
  }

  logger.info('tokens', 'Usage statistics reset')
end

return M
