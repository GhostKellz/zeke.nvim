-- Test script for zeke.nvim HTTP client
-- Usage: nvim --headless -c "luafile test_http_connection.lua" -c "q"

print("=== Zeke.nvim HTTP Client Test ===\n")

-- Add lua directory to path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Test 1: Load the http_client module
print("[TEST 1] Loading http_client module...")
local ok, http = pcall(require, "zeke.http_client")
if not ok then
  print("❌ FAILED: Could not load http_client module")
  print("Error: " .. tostring(http))
  os.exit(1)
end
print("✅ PASSED: http_client module loaded\n")

-- Test 2: Check if plenary is available
print("[TEST 2] Checking for plenary.nvim...")
local has_plenary, curl = pcall(require, "plenary.curl")
if not has_plenary then
  print("❌ FAILED: plenary.nvim is not installed")
  print("Please install: https://github.com/nvim-lua/plenary.nvim")
  os.exit(1)
end
print("✅ PASSED: plenary.nvim is installed\n")

-- Test 3: Test connection to Zeke HTTP API
print("[TEST 3] Testing connection to " .. http.base_url .. "...")
local success, result = pcall(http.health)

if success and result.status == "ok" then
  print("✅ PASSED: Connected to Zeke server")
  print("   Version: " .. (result.version or "unknown"))
  print("")
else
  print("❌ FAILED: Could not connect to Zeke server")
  print("   Make sure the Zeke server is running:")
  print("   $ zeke serve")
  print("")
  print("   Error: " .. tostring(result))
  os.exit(1)
end

-- Test 4: Test chat endpoint (optional - requires server)
print("[TEST 4] Testing /api/chat endpoint...")
local chat_ok, chat_result = pcall(http.chat, "Hello, this is a test", {
  model = "smart",
  intent = "explain",
})

if chat_ok and chat_result.response then
  print("✅ PASSED: Chat endpoint working")
  print("   Model: " .. (chat_result.model or "unknown"))
  print("   Provider: " .. (chat_result.provider or "unknown"))
  print("   Latency: " .. (chat_result.latency_ms or 0) .. "ms")
  print("   Response length: " .. #chat_result.response .. " chars")
  print("")
else
  print("⚠️  WARNING: Chat endpoint failed (this is OK if no AI providers are configured)")
  print("   Error: " .. tostring(chat_result))
  print("")
end

print("=== Test Complete ===")
print("All critical tests passed! ✅")
print("\nYou can now use zeke.nvim in Neovim:")
print("  :ZekeChat hello world")
print("  :ZekeExplain")
print("  :ZekeEdit add type hints")
