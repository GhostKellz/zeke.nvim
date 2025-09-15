local M = {}

local terminal = require('zeke.terminal')
local ui = require('zeke.ui')
local workspace = require('zeke.workspace')
local diff = require('zeke.diff')
local zeke_nvim = nil

function M.setup(rust_module)
  zeke_nvim = rust_module
end

function M.chat(message)
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  -- If no message provided, open chat UI
  if not message or message == '' then
    ui.open_chat()
    return
  end

  -- Add workspace context if available
  local context_prompt = workspace.build_context_prompt()
  local full_message = message .. context_prompt

  vim.notify('Processing chat request...', vim.log.levels.INFO)

  local ok, response = pcall(zeke_nvim.chat, full_message)
  if ok then
    terminal.show_response(response)
  else
    vim.notify('Chat failed: ' .. tostring(response), vim.log.levels.ERROR)
  end
end

function M.edit_buffer(instruction)
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code = table.concat(lines, '\n')

  if not instruction or instruction == '' then
    vim.ui.input({prompt = 'Edit instruction: '}, function(input)
      if input then M.edit_buffer(input) end
    end)
    return
  end

  vim.notify('Processing edit request...', vim.log.levels.INFO)

  -- Add workspace context
  local context_prompt = workspace.build_context_prompt()
  local full_instruction = instruction .. context_prompt

  local ok, response = pcall(zeke_nvim.edit_code, code, full_instruction)
  if ok then
    -- Show diff view instead of simple response
    diff.show_ai_edit_diff(response)
  else
    vim.notify('Edit failed: ' .. tostring(response), vim.log.levels.ERROR)
  end
end

function M.explain(code)
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  if not code then
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    code = table.concat(lines, '\n')
  end

  vim.notify('Generating explanation...', vim.log.levels.INFO)

  local ok, response = pcall(zeke_nvim.explain_code, code)
  if ok then
    terminal.show_response(response)
  else
    vim.notify('Explain failed: ' .. tostring(response), vim.log.levels.ERROR)
  end
end

function M.create_file(description)
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  if not description or description == '' then
    vim.ui.input({prompt = 'File description: '}, function(input)
      if input then M.create_file(input) end
    end)
    return
  end

  vim.notify('Generating file content...', vim.log.levels.INFO)

  local ok, response = pcall(zeke_nvim.create_file, description)
  if ok then
    terminal.show_response(response)

    vim.ui.input({
      prompt = 'Enter filename (or press Esc to cancel): ',
    }, function(filename)
      if filename and filename ~= '' then
        vim.ui.select({'Yes', 'No'}, {
          prompt = string.format('Create file "%s"?', filename),
        }, function(choice)
          if choice == 'Yes' then
            M.create_file_with_content(filename, response)
          end
        end)
      end
    end)
  else
    vim.notify('Create failed: ' .. tostring(response), vim.log.levels.ERROR)
  end
end

function M.analyze(analysis_type, code)
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  if not code then
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    code = table.concat(lines, '\n')
  end

  analysis_type = analysis_type or 'quality'

  vim.notify('Analyzing code...', vim.log.levels.INFO)

  local ok, response = pcall(zeke_nvim.analyze_code, code, analysis_type)
  if ok then
    terminal.show_response(response)
  else
    vim.notify('Analysis failed: ' .. tostring(response), vim.log.levels.ERROR)
  end
end

function M.apply_edit_to_buffer(buf, content)
  local code_blocks = M.extract_code_blocks(content)

  if #code_blocks == 0 then
    vim.notify('No code blocks found in response', vim.log.levels.WARN)
    return
  end

  local code_block = code_blocks[1]
  local lines = vim.split(code_block, '\n', { plain = true })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.notify('Changes applied to buffer', vim.log.levels.INFO)
end

function M.extract_code_blocks(content)
  local code_blocks = {}
  local in_code_block = false
  local current_block = {}

  for line in content:gmatch('[^\r\n]+') do
    if line:match('^```') then
      if in_code_block then
        table.insert(code_blocks, table.concat(current_block, '\n'))
        current_block = {}
        in_code_block = false
      else
        in_code_block = true
      end
    elseif in_code_block then
      table.insert(current_block, line)
    end
  end

  return code_blocks
end

function M.create_file_with_content(filename, content)
  local code_blocks = M.extract_code_blocks(content)
  local file_content = #code_blocks > 0 and code_blocks[1] or content

  local file = io.open(filename, 'w')
  if file then
    file:write(file_content)
    file:close()
    vim.notify(string.format('File created: %s', filename), vim.log.levels.INFO)

    vim.ui.select({'Yes', 'No'}, {
      prompt = 'Open the created file?',
    }, function(choice)
      if choice == 'Yes' then
        vim.cmd('edit ' .. filename)
      end
    end)
  else
    vim.notify(string.format('Failed to create file: %s', filename), vim.log.levels.ERROR)
  end
end

function M.list_models()
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  local ok, models = pcall(zeke_nvim.list_models)
  if ok then
    local model_list = {'Available models:'}
    for _, model in ipairs(models) do
      table.insert(model_list, '  • ' .. model)
    end
    terminal.show_response(table.concat(model_list, '\n'))
  else
    vim.notify('Failed to list models: ' .. tostring(models), vim.log.levels.ERROR)
  end
end

function M.set_model(model_name)
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  if not model_name or model_name == '' then
    vim.ui.input({
      prompt = 'Enter model name: ',
    }, function(input)
      if input then
        M.set_model(input)
      end
    end)
    return
  end

  local ok, err = pcall(zeke_nvim.set_model, model_name)
  if ok then
    vim.notify('Model updated to: ' .. model_name, vim.log.levels.INFO)
  else
    vim.notify('Failed to set model: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.get_current_model()
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  local ok, model = pcall(zeke_nvim.get_current_model)
  if ok then
    vim.notify('Current model: ' .. model, vim.log.levels.INFO)
  else
    vim.notify('Failed to get current model: ' .. tostring(model), vim.log.levels.ERROR)
  end
end

function M.list_tasks()
  terminal.list_tasks()
end

function M.cancel_task(task_id)
  terminal.cancel_task(task_id)
end

function M.cancel_all_tasks()
  terminal.cancel_all_tasks()
end

function M.chat_stream(message)
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  if not message or message == '' then
    vim.ui.input({prompt = 'Streaming chat message: '}, function(input)
      if input then M.chat_stream(input) end
    end)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Zeke Streaming Chat')
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')

  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)

  local content_lines = {'Streaming response...', ''}
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)

  local function on_chunk(chunk)
    table.insert(content_lines, chunk)
    vim.schedule(function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)
      vim.cmd('normal! G')
    end)
  end

  local ok, err = pcall(zeke_nvim.chat_stream, message, on_chunk)
  if not ok then
    vim.notify('Streaming chat failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

-- New workspace and UI commands
function M.toggle_chat()
  ui.toggle_chat()
end

function M.add_file_to_context()
  workspace.file_picker()
end

function M.add_current_file_to_context()
  workspace.add_current_file()
end

function M.add_selection_to_context()
  workspace.add_selection()
end

function M.show_context()
  local summary = workspace.get_context_summary()
  vim.notify(summary, vim.log.levels.INFO)
end

function M.clear_context()
  workspace.clear_context()
end

function M.show_context_files()
  workspace.show_context_files()
end

function M.save_conversation()
  ui.save_conversation()
end

function M.list_conversations()
  ui.list_conversations()
end

function M.set_provider(provider)
  if not zeke_nvim then
    vim.notify('Zeke not initialized', vim.log.levels.ERROR)
    return
  end

  if not provider or provider == '' then
    vim.ui.select({'openai', 'claude', 'copilot', 'ollama'}, {
      prompt = 'Select AI provider:',
    }, function(choice)
      if choice then
        M.set_provider(choice)
      end
    end)
    return
  end

  -- Note: This would need to be implemented in the Rust side
  vim.notify('Provider set to: ' .. provider, vim.log.levels.INFO)
end

function M.workspace_search(query)
  if not query or query == '' then
    vim.ui.input({prompt = 'Search files: '}, function(input)
      if input then M.workspace_search(input) end
    end)
    return
  end

  local results = workspace.search_files(query)
  if #results == 0 then
    vim.notify('No files found matching: ' .. query, vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, result in ipairs(results) do
    table.insert(items, result.relative_path)
  end

  vim.ui.select(items, {
    prompt = 'Select file to add to context:',
  }, function(choice, idx)
    if idx then
      workspace.add_file_to_context(results[idx].path)
    end
  end)
end

return M