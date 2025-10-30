--[[
  Error Message Improvements

  Provides helpful, actionable error messages instead of generic failures.
--]]

local M = {}

---Parse common error patterns and return helpful messages
---@param error_msg string Raw error message
---@return string Helpful error message
---@return string|nil Suggested action
function M.parse_error(error_msg)
  if not error_msg then
    return "Unknown error occurred", "Check :ZekeHealth for system status"
  end

  local error_lower = error_msg:lower()

  -- Rate limiting
  if error_lower:match("rate limit") or error_lower:match("429") or error_lower:match("too many requests") then
    return "⚠️  Rate Limit Exceeded",
      "You've sent too many requests. Wait 30-60 seconds and try again.\n" ..
      "Check rate limits with :ZekeSafety\n" ..
      "Consider using a local model: :ZekeModels → qwen2.5-coder:7b"
  end

  -- Authentication errors
  if error_lower:match("unauthorized") or error_lower:match("401") or error_lower:match("invalid.*api.*key") or error_lower:match("authentication") then
    return "🔐 Authentication Failed",
      "Your API key is invalid or missing.\n" ..
      "Fix:\n" ..
      "1. Check ~/.config/zeke/zeke.toml\n" ..
      "2. Ensure API key is set for current provider\n" ..
      "3. Verify key is active and has credits\n" ..
      "Run :ZekeHealth to check configuration"
  end

  -- Permission errors
  if error_lower:match("forbidden") or error_lower:match("403") then
    return "🚫 Permission Denied",
      "You don't have permission to use this model or feature.\n" ..
      "Possible causes:\n" ..
      "- API key lacks necessary permissions\n" ..
      "- Model not available on your plan\n" ..
      "- Organization/project restrictions\n" ..
      "Try switching models: :ZekeModels"
  end

  -- Network errors
  if error_lower:match("connection") or error_lower:match("network") or error_lower:match("unreachable") then
    return "🌐 Network Error",
      "Cannot connect to AI service.\n" ..
      "Check:\n" ..
      "1. Internet connection\n" ..
      "2. Firewall settings\n" ..
      "3. VPN configuration\n" ..
      "4. Service status (provider website)\n" ..
      "Try using local model: :ZekeModels → qwen2.5-coder:7b"
  end

  -- Timeout errors
  if error_lower:match("timeout") or error_lower:match("timed out") then
    return "⏱️  Request Timeout",
      "Request took too long to complete.\n" ..
      "Suggestions:\n" ..
      "- Try again (may be temporary)\n" ..
      "- Reduce prompt size (currently: " .. math.floor(#error_msg / 4) .. " tokens estimated)\n" ..
      "- Use faster model: :ZekeModels\n" ..
      "Automatic retry in progress..."
  end

  -- Model not found
  if error_lower:match("model.*not found") or error_lower:match("404") then
    return "🤖 Model Not Found",
      "The selected model doesn't exist or isn't available.\n" ..
      "Fix:\n" ..
      "1. Check model name: :ZekeModelInfo\n" ..
      "2. View available models: :ZekeModels\n" ..
      "3. For Ollama: run 'ollama list' to see installed models\n" ..
      "Popular models:\n" ..
      "- claude-sonnet-4 (Anthropic)\n" ..
      "- gpt-4o (OpenAI)\n" ..
      "- qwen2.5-coder:7b (Ollama, local)"
  end

  -- Service unavailable
  if error_lower:match("503") or error_lower:match("service unavailable") or error_lower:match("overloaded") then
    return "⚙️  Service Temporarily Unavailable",
      "The AI service is experiencing issues.\n" ..
      "This is usually temporary. Will retry automatically.\n" ..
      "- Wait a few minutes and try again\n" ..
      "- Check provider status page\n" ..
      "- Try different model: :ZekeModels\n" ..
      "View retry status: :ZekeRequests"
  end

  -- Gateway timeout
  if error_lower:match("504") or error_lower:match("gateway timeout") then
    return "🚪 Gateway Timeout",
      "The request couldn't be completed in time.\n" ..
      "Will retry automatically with exponential backoff.\n" ..
      "If this persists:\n" ..
      "- Reduce context size (fewer @file: mentions)\n" ..
      "- Use shorter prompts\n" ..
      "- Try faster model\n" ..
      "Check retry status: :ZekeRequests"
  end

  -- Context length errors
  if error_lower:match("context.*length") or error_lower:match("maximum.*token") or error_lower:match("too.*long") then
    return "📏 Context Too Large",
      "Your prompt exceeds the model's context window.\n" ..
      "Solutions:\n" ..
      "- Remove some @file: mentions\n" ..
      "- Shorten your message\n" ..
      "- Use model with larger context: :ZekeModels\n" ..
      "  → claude-opus-4 (200K tokens)\n" ..
      "  → gemini-1.5-pro (1M tokens)\n" ..
      "Check token usage: :ZekeTokens"
  end

  -- File errors
  if error_lower:match("no such file") or error_lower:match("file not found") then
    return "📁 File Not Found",
      "Cannot find the specified file.\n" ..
      "Check:\n" ..
      "1. File path is correct\n" ..
      "2. File exists: ls <path>\n" ..
      "3. You have read permissions\n" ..
      "4. Working directory is correct: :pwd"
  end

  -- Parse errors
  if error_lower:match("parse") or error_lower:match("invalid.*json") or error_lower:match("malformed") then
    return "🔧 Response Parse Error",
      "Received invalid response from AI service.\n" ..
      "This is usually a temporary issue.\n" ..
      "Try:\n" ..
      "- Send request again\n" ..
      "- Rephrase your prompt\n" ..
      "- Use different model: :ZekeModels\n" ..
      "If persists, this may be a bug. Report at:\n" ..
      "https://github.com/ghostkellz/zeke.nvim/issues"
  end

  -- Generic server error
  if error_lower:match("500") or error_lower:match("internal server error") then
    return "💥 Server Error",
      "The AI service encountered an internal error.\n" ..
      "This is a provider-side issue, not zeke.nvim.\n" ..
      "Will retry automatically.\n" ..
      "If this persists:\n" ..
      "- Check provider status page\n" ..
      "- Try different provider: :ZekeModels\n" ..
      "- Report if recurring\n" ..
      "View retry attempts: :ZekeRequests"
  end

  -- Ollama specific
  if error_lower:match("ollama") then
    if error_lower:match("connection refused") or error_lower:match("connect.*localhost:11434") then
      return "🦙 Ollama Not Running",
        "Cannot connect to Ollama server.\n" ..
        "Fix:\n" ..
        "1. Start Ollama: ollama serve\n" ..
        "2. Or install: https://ollama.ai\n" ..
        "3. Pull model: ollama pull qwen2.5-coder:7b\n" ..
        "4. Verify: ollama list\n" ..
        "Or use cloud provider: :ZekeModels"
    end

    if error_lower:match("model.*not found") then
      return "🦙 Ollama Model Not Installed",
        "The model isn't installed locally.\n" ..
        "Install with:\n" ..
        "  ollama pull qwen2.5-coder:7b\n" ..
        "\n" ..
        "Popular models:\n" ..
        "  ollama pull qwen2.5-coder:7b    # Fast, code-focused\n" ..
        "  ollama pull deepseek-coder-v2:16b  # Larger, better\n" ..
        "  ollama pull codellama:13b       # Good balance\n" ..
        "\n" ..
        "View installed: ollama list"
    end
  end

  -- Default: return original with generic help
  return "❌ Request Failed",
    "Error: " .. error_msg .. "\n\n" ..
    "Troubleshooting:\n" ..
    "1. Check system health: :ZekeHealth\n" ..
    "2. View request details: :ZekeRequests\n" ..
    "3. Verify configuration: ~/.config/zeke/zeke.toml\n" ..
    "4. Try different model: :ZekeModels\n" ..
    "5. Check logs: ~/.local/share/nvim/zeke/logs\n\n" ..
    "If issue persists, report at:\n" ..
    "https://github.com/ghostkellz/zeke.nvim/issues"
end

---Show helpful error notification
---@param error_msg string Raw error message
---@param level number|nil Vim log level (default: ERROR)
function M.show(error_msg, level)
  level = level or vim.log.levels.ERROR

  local title, help = M.parse_error(error_msg)

  local message = title .. "\n\n" .. help

  vim.notify(message, level)
end

---Get error with retry context
---@param error_msg string Raw error
---@param attempt number Current attempt
---@param max_attempts number Max attempts
---@return string Formatted error with retry info
function M.with_retry_context(error_msg, attempt, max_attempts)
  local title, help = M.parse_error(error_msg)

  return string.format(
    "%s\n\nAttempt %d/%d failed.\n%s",
    title,
    attempt,
    max_attempts,
    help
  )
end

return M
