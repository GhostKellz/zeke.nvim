-- Example packer.nvim configuration for zeke.nvim

-- ============================================================================
-- packer.nvim setup
-- ============================================================================

-- Install packer if not present
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

-- ============================================================================
-- Plugin configuration
-- ============================================================================

return require('packer').startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- zeke.nvim
  use {
    'ghostkellz/zeke.nvim',
    requires = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('zeke').setup({
        -- HTTP API Configuration
        http_api = {
          base_url = "http://localhost:7878",
          timeout = 30000,
        },

        -- Default model
        default_model = 'smart',

        -- Keymaps
        keymaps = {
          chat = '<leader>zc',
          edit = '<leader>ze',
          explain = '<leader>zx',
          create = '<leader>zf',
          analyze = '<leader>za',
        },

        -- Logging
        logger = {
          level = "INFO",
        },

        -- Lock file
        create_lockfile = true,
      })
    end
  }

  -- Automatically set up configuration after cloning packer.nvim
  if packer_bootstrap then
    require('packer').sync()
  end
end)
