if vim.g.loaded_zeke then
  return
end
vim.g.loaded_zeke = 1

vim.api.nvim_create_user_command('Zeke', function(opts)
  local args = vim.split(opts.args, ' ', { trimempty = true })
  local subcommand = args[1]

  if not subcommand then
    vim.notify('Zeke: Please specify a subcommand', vim.log.levels.ERROR)
    return
  end

  local zeke = require('zeke')

  if subcommand == 'setup' then
    zeke.setup()
  elseif subcommand == 'chat' then
    local message = table.concat(vim.list_slice(args, 2), ' ')
    zeke.chat(message)
  elseif subcommand == 'edit' then
    local instruction = table.concat(vim.list_slice(args, 2), ' ')
    zeke.edit(instruction)
  elseif subcommand == 'explain' then
    zeke.explain()
  elseif subcommand == 'create' then
    local description = table.concat(vim.list_slice(args, 2), ' ')
    zeke.create(description)
  elseif subcommand == 'analyze' then
    local analysis_type = args[2] or 'quality'
    zeke.analyze(analysis_type)
  elseif subcommand == 'models' then
    zeke.list_models()
  elseif subcommand == 'model' then
    if args[2] then
      zeke.set_model(args[2])
    else
      zeke.get_current_model()
    end
  elseif subcommand == 'tasks' then
    zeke.list_tasks()
  elseif subcommand == 'cancel' then
    if args[2] then
      zeke.cancel_task(tonumber(args[2]))
    else
      zeke.cancel_all_tasks()
    end
  else
    vim.notify('Zeke: Unknown subcommand: ' .. subcommand, vim.log.levels.ERROR)
  end
end, {
  nargs = '+',
  desc = 'Zeke AI assistant commands',
  complete = function(_, cmdline, _)
    local args = vim.split(cmdline, ' ', { trimempty = true })

    if #args == 2 then
      local subcommands = {
        'setup', 'chat', 'edit', 'explain', 'create', 'analyze',
        'models', 'model', 'tasks', 'cancel'
      }
      return vim.tbl_filter(function(cmd)
        return cmd:find('^' .. args[2])
      end, subcommands)
    elseif #args == 3 and args[2] == 'analyze' then
      return { 'quality', 'performance', 'security', 'complexity' }
    end

    return {}
  end,
})