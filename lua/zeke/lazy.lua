-- Optimized lazy.nvim configuration for zeke.nvim
-- Drop this into your lazy.nvim config for best performance

return {
  "ghostkellz/zeke.nvim",

  -- Load on command for faster startup
  cmd = {
    "ZekeChat",
    "ZekeChatUI",
    "ZekeEdit",
    "ZekeExplain",
    "ZekeCreate",
    "ZekeAnalyze",
    "ZekeFix",
    "ZekeOptimize",
    "ZekeDocs",
    "ZekeTests",
    "ZekeCommit",
    "ZekeRefactor",
    "ZekeReview",
    "ZekeModel",
    "ZekeModels",
    "ZekeSetModel",
    "ZekeCurrentModel",
    "ZekeDiffAccept",
    "ZekeDiffReject",
    "ZekeDiffClose",
  },

  -- Also load on these keymaps
  keys = {
    { "<leader>zc", "<cmd>ZekeChatUI<cr>", desc = "Zeke: Open Chat" },
    { "<leader>ze", "<cmd>ZekeEdit<cr>", desc = "Zeke: Edit Buffer" },
    { "<leader>zx", "<cmd>ZekeExplain<cr>", desc = "Zeke: Explain Code" },
    { "<leader>za", "<cmd>ZekeAnalyze<cr>", desc = "Zeke: Analyze Code" },
    { "<leader>zm", "<cmd>ZekeModel<cr>", desc = "Zeke: Select Model" },
    { "<leader>zf", "<cmd>ZekeFix<cr>", desc = "Zeke: Fix Issues" },
    { "<leader>zo", "<cmd>ZekeOptimize<cr>", desc = "Zeke: Optimize Code" },
    { "<leader>zd", "<cmd>ZekeDocs<cr>", desc = "Zeke: Add Documentation" },
    { "<leader>zt", "<cmd>ZekeTests<cr>", desc = "Zeke: Generate Tests" },
    { "<leader>zr", "<cmd>ZekeReview<cr>", desc = "Zeke: Code Review" },

    -- Visual mode mappings
    { "<leader>ze", ":<C-u>ZekeEdit<cr>", mode = "v", desc = "Zeke: Edit Selection" },
    { "<leader>zx", ":<C-u>ZekeExplain<cr>", mode = "v", desc = "Zeke: Explain Selection" },
    { "<leader>zf", ":<C-u>ZekeFix<cr>", mode = "v", desc = "Zeke: Fix Selection" },
    { "<leader>zo", ":<C-u>ZekeOptimize<cr>", mode = "v", desc = "Zeke: Optimize Selection" },
  },

  dependencies = {
    "nvim-lua/plenary.nvim", -- Required for HTTP client
  },

  -- Build Zig binary (optional - only if using Zig features)
  build = "zig build -Doptimize=ReleaseSafe",

  opts = {
    -- Zeke HTTP API connection
    http_api = {
      base_url = "http://localhost:7878",
      timeout = 30000, -- 30 seconds
    },

    -- Default model from zeke.toml
    default_model = "smart", -- 'smart', 'fast', 'auto', or specific model

    -- UI settings
    auto_reload = true, -- Auto-reload files after AI edits

    -- Logging (DEBUG, INFO, WARN, ERROR)
    logger = {
      level = "INFO",
      file = vim.fn.stdpath("cache") .. "/zeke.log",
      show_timestamp = true,
    },

    -- Selection tracking
    selection = {
      track_selection = true,
      debounce_ms = 100,
      visual_demotion_delay_ms = 50,
    },

    -- Diff management
    diff = {
      keep_terminal_focus = false,
      open_in_new_tab = false,
      auto_close_on_accept = true,
      show_diff_stats = true,
      vertical_split = true,
    },

    -- Keymaps (set to false to disable default keymaps)
    keymaps = {
      enabled = true,
      prefix = "<leader>z", -- Change to your preferred prefix
    },

    -- Disable if you don't want keymaps
    -- keymaps = { enabled = false },
  },

  config = function(_, opts)
    require("zeke").setup(opts)
  end,
}
