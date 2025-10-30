--[[
  Statusline Integration

  Features:
  - Show current model/provider
  - Token usage statistics
  - Request progress indicators
  - Rate limiting status
  - Lualine component support
--]]

local M = {}

local models = require('zeke.models')
local tokens = require('zeke.tokens')
local requests = require('zeke.requests')
local safety = require('zeke.safety')

-- Configuration
M.config = {
  enabled = true,
  show_model = true,
  show_tokens = true,
  show_requests = true,
  show_rate_limit = true,
  icons = {
    model = '🤖',
    tokens = '💰',
    request = '⚡',
    rate_limit_ok = '🟢',
    rate_limit_warn = '🟡',
    rate_limit_critical = '🔴',
  },
}

---Setup statusline integration
---@param opts table|nil Configuration options
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)
end

---Get current model info
---@return string Model name with icon
function M.get_model()
  if not M.config.show_model then
    return ''
  end

  local current_model = models.get_current()
  if not current_model then
    return ''
  end

  return string.format(
    '%s %s',
    current_model.icon or M.config.icons.model,
    current_model.name
  )
end

---Get token usage info
---@return string Token usage summary
function M.get_tokens()
  if not M.config.show_tokens then
    return ''
  end

  local stats = tokens.get_usage_stats()

  if stats.requests == 0 then
    return ''
  end

  -- Show cost if non-zero
  if stats.total_cost > 0 then
    return string.format(
      '%s $%.2f',
      M.config.icons.tokens,
      stats.total_cost
    )
  end

  -- Just show token count for free models
  return string.format(
    '%s %dk',
    M.config.icons.tokens,
    math.floor(stats.total_tokens / 1000)
  )
end

---Get active request info
---@return string Active request summary
function M.get_requests()
  if not M.config.show_requests then
    return ''
  end

  local active = requests.get_active()

  if #active == 0 then
    return ''
  end

  -- Show count and state of first request
  local first = active[1]
  local state_icon = first.state == requests.State.IN_PROGRESS and '⚡' or
                     first.state == requests.State.RETRYING and '🔄' or '⏳'

  if #active == 1 then
    return string.format('%s %s', state_icon, first.state)
  else
    return string.format('%s %s (+%d)', state_icon, first.state, #active - 1)
  end
end

---Get rate limit status
---@return string Rate limit indicator
function M.get_rate_limit()
  if not M.config.show_rate_limit then
    return ''
  end

  local stats = safety.get_rate_stats()

  if stats.requests_last_minute == 0 then
    return ''
  end

  local icon = stats.is_critical and M.config.icons.rate_limit_critical or
               stats.is_warning and M.config.icons.rate_limit_warn or
               M.config.icons.rate_limit_ok

  return string.format('%s %d/min', icon, stats.requests_last_minute)
end

---Get full statusline component
---@return string Complete statusline
function M.get_statusline()
  if not M.config.enabled then
    return ''
  end

  local parts = {}

  local model = M.get_model()
  if model ~= '' then
    table.insert(parts, model)
  end

  local tokens_info = M.get_tokens()
  if tokens_info ~= '' then
    table.insert(parts, tokens_info)
  end

  local requests_info = M.get_requests()
  if requests_info ~= '' then
    table.insert(parts, requests_info)
  end

  local rate_limit = M.get_rate_limit()
  if rate_limit ~= '' then
    table.insert(parts, rate_limit)
  end

  if #parts == 0 then
    return ''
  end

  return table.concat(parts, ' │ ')
end

---Lualine component: model
---@return string Model info
function M.lualine_model()
  return M.get_model()
end

---Lualine component: tokens
---@return string Token info
function M.lualine_tokens()
  return M.get_tokens()
end

---Lualine component: requests
---@return string Request info
function M.lualine_requests()
  return M.get_requests()
end

---Lualine component: rate limit
---@return string Rate limit info
function M.lualine_rate_limit()
  return M.get_rate_limit()
end

---Lualine component: full status
---@return string Complete status
function M.lualine_status()
  return M.get_statusline()
end

---Get lualine components configuration
---@return table Lualine component config
function M.get_lualine_components()
  return {
    -- Individual components
    zeke_model = {
      M.lualine_model,
      cond = function() return M.config.show_model end,
    },
    zeke_tokens = {
      M.lualine_tokens,
      cond = function() return M.config.show_tokens and M.get_tokens() ~= '' end,
    },
    zeke_requests = {
      M.lualine_requests,
      cond = function() return M.config.show_requests and M.get_requests() ~= '' end,
    },
    zeke_rate_limit = {
      M.lualine_rate_limit,
      cond = function() return M.config.show_rate_limit and M.get_rate_limit() ~= '' end,
    },
    -- Combined component
    zeke_status = {
      M.lualine_status,
      cond = function() return M.config.enabled and M.get_statusline() ~= '' end,
    },
  }
end

---Setup lualine integration
---@param lualine_config table Lualine configuration
---@return table Modified lualine config
function M.setup_lualine(lualine_config)
  lualine_config = lualine_config or {}

  -- Add zeke status to lualine_x or lualine_c
  if not lualine_config.sections then
    lualine_config.sections = {}
  end

  if not lualine_config.sections.lualine_x then
    lualine_config.sections.lualine_x = {}
  end

  -- Add zeke status component
  table.insert(lualine_config.sections.lualine_x, M.lualine_status)

  return lualine_config
end

---Update statusline (useful for autocommands)
function M.update()
  -- Force statusline redraw
  vim.cmd('redrawstatus')
end

---Setup autocommands for statusline updates
function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup('ZekeStatusline', { clear = true })

  -- Update on various events
  vim.api.nvim_create_autocmd({ 'User' }, {
    group = group,
    pattern = 'ZekeRequestStart',
    callback = function()
      M.update()
    end,
  })

  vim.api.nvim_create_autocmd({ 'User' }, {
    group = group,
    pattern = 'ZekeRequestComplete',
    callback = function()
      M.update()
    end,
  })

  vim.api.nvim_create_autocmd({ 'User' }, {
    group = group,
    pattern = 'ZekeModelChanged',
    callback = function()
      M.update()
    end,
  })

  -- Periodic update (every 5 seconds for rate limiting)
  local timer = vim.loop.new_timer()
  timer:start(5000, 5000, vim.schedule_wrap(function()
    M.update()
  end))
end

-- Initialize
M.setup()

return M
