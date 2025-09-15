-- Simple test script to verify the plugin works
local zeke = require('zeke')

print("Setting up Zeke plugin...")

-- Test configuration
zeke.setup({
    default_provider = 'openai',
    default_model = 'gpt-4',
    api_keys = {
        openai = os.getenv('OPENAI_API_KEY') or 'test-key',
    },
    keymaps = {
        chat = '<leader>zc',
        edit = '<leader>ze',
    }
})

print("Zeke plugin setup complete!")
print("Available functions:")
print("- zeke.chat(message)")
print("- zeke.edit(instruction)")
print("- zeke.explain()")
print("- zeke.create(description)")
print("- zeke.analyze(type)")
print("- zeke.list_models()")
print("- zeke.set_model(model)")
print("- zeke.get_current_model()")

-- Test basic functionality (without actual API calls)
print("\nTesting model management...")
local models = zeke.list_models()
if models then
    print("Available models:")
    for i, model in ipairs(models) do
        print("  " .. i .. ". " .. model)
    end
end

local current_model = zeke.get_current_model()
if current_model then
    print("Current model: " .. current_model)
end

print("\nZeke.nvim test completed successfully!")