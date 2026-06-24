local M = {}
M.ALL = {
  "bootstrap",
}

M.opts = {}
M.configs = {
  -- Mason: external tooling packge manager {{{
  -- {
  --     'williamboman/mason.nvim',
  --     dependencies = {
  --         'neovim/nvim-lspconfig',
  --         'williamboman/mason-lspconfig.nvim',
  --     },
  --     config = function()
  --         require('mason').setup({
  --             ui = {
  --                 icons = {
  --                     package_installed = "✓",
  --                     package_pending = "➜",
  --                     package_uninstalled = "✗",
  --                 }
  --             }
  --         })
  --     end
  -- },
  -- }}}
  -- LSP Symbols {{{
  {
    "simrat39/symbols-outline.nvim",
    priority = 0,
    config = function()
      require("symbols-outline").setup()
    end,
  },
  -- }}}
  -- LSP Diagnostic Lines {{{
  {
    "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    config = function()
      local lsp_lines = require("lsp_lines")
      lsp_lines.setup()
      -- Disable default diagnostics as it's redundant with this plugin
      vim.diagnostic.config({ virtual_text = false })
      -- Set diagnostic virtual text colorscheme
      vim.api.nvim_create_augroup("ColorLspLines", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", {
        command = "hi link DiagnosticVirtualTextError DiagnosticFloatingError",
        group = "ColorLspLines",
      })
      vim.api.nvim_create_autocmd("ColorScheme", {
        command = "hi link DiagnosticVirtualTextWarn DiagnosticFloatingWarn",
        group = "ColorLspLines",
      })
      vim.api.nvim_create_autocmd("ColorScheme", {
        command = "hi link DiagnosticVirtualTextInfo DiagnosticFloatingInfo",
        group = "ColorLspLines",
      })
      vim.api.nvim_create_autocmd("ColorScheme", {
        command = "hi link DiagnosticVirtualTextHint DiagnosticFloatingHint",
        group = "ColorLspLines",
      })
    end,
  },
  -- }}}

  -- Treesitter {{{
  -- {
  --     'nvim-treesitter/nvim-treesitter',
  --     build = function () vim.cmd('TSUpdate') end,
  --     config = function ()
  --         require('nvim-treesitter.configs').setup({
  --             ensure_installed = {
  --                 "html",
  --                 "lua",
  --                 "luadoc",
  --                 "python",
  --                 "markdown",
  --                 "markdown_inline",
  --                 "regex",
  --                 "tmux",
  --                 "xml",
  --                 "yaml",
  --             },
  --             highlight = { enable = true },
  --             indent = { enable = true },
  --             incremental_selection = { enable = true },
  --             textobjects = { enable = true },
  --         })
  --     end
  -- },
  -- }}}

  -- BQF provides a better quickfix list {{{
  {
    "kevinhwang91/nvim-bqf",
    config = function()
      require("bqf").setup({})
    end,
  },
  -- }}}
  -- Bufferline adds fancy tabs for buffers {{{
  {
    "akinsho/bufferline.nvim", --tag = "v3.*",
    dependencies = { "kyazdani42/nvim-web-devicons", lazy = true },
    config = function()
      require("bufferline").setup({
        options = {
          numbers = "buffer_id",
          diagnostics = "nvim_lsp",
          diagnostics_indicator = function(count, level)
            local icon = level:match("error") and "" or ""
            return " " .. icon .. count
          end,
        },
      })
    end,
  },
  -- }}}
  -- Colorizer automatically highlights color codes {{{
  {
    "norcalli/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup(nil, {
        --names = false,
      })
    end,
  },
  -- }}}
  -- Comment is a simple commenting plugin for Neovim {{{
  {
    "numToStr/Comment.nvim",
    opts = {
      -- add any options here
    },
    lazy = false,
  },
  -- }}}
  -- Dressing improves nvim UI default interfaces (like using Telescope) {{{
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy", -- Load last
    config = function()
      require("dressing").setup()
    end,
  },
  -- }}}
  -- Fidget provides a progress indicator for the LSP {{{
  {
    "j-hui/fidget.nvim",
    tag = "legacy", -- TODO: check for new rewritten version
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      require("fidget").setup()
    end,
  },
  -- }}}
  -- Fugitive is a Git wrapper for Vim {{{
  "tpope/vim-fugitive",
  -- }}}
  -- Gitsigns provides Git diff and blame info {{{
  {
    "lewis6991/gitsigns.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "VeryLazy",
    config = function()
      require("gitsigns").setup({ yadm = { enable = true } })
    end,
  },
  -- }}}
  -- Gruvbox is a colorscheme for Vim {{{
  {
    "sainnhe/gruvbox-material",
    lazy = false,
    priority = 1000, -- Load colorscheme first
    init = function()
      vim.opt.termguicolors = true
      vim.opt.background = "dark"
      -- Use terminal background
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
          vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
          vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
          vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
          vim.api.nvim_set_hl(0, "FloatTitle", { bg = "none" })
          vim.api.nvim_set_hl(0, "FloatFooter", { bg = "none" })
          vim.api.nvim_set_hl(0, "FoldColumn", { bg = "none" })
          vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
        end,
      })
      -- Enable
      vim.g["gruvbox_material_better_performance"] = 1
      vim.api.nvim_command("colorscheme gruvbox-material")
    end,
  },
  -- }}}
  -- IndentLine provides an indentation guide {{{
  {
    "Yggdroot/indentLine",
    config = function()
      vim.g["indentLine_char"] = "┆"
    end,
  },
  -- }}}
  -- Lualine provides a better status line and a tab bar, in Lua {{{
  {
    "hoob3rt/lualine.nvim",
    dependencies = { "kyazdani42/nvim-web-devicons", lazy = true },
    config = function()
      local function get_git_status()
        local status_dict = vim.b["gitsigns_status_dict"]
        if not status_dict then
          return {}
        else
          return {
            added = status_dict.added,
            modified = status_dict.changed,
            removed = status_dict.removed,
          }
        end
      end
      require("lualine").setup({
        sections = {
          lualine_a = {
            "mode",
            {
              function()
                return "ᑭ"
              end,
              cond = function()
                return vim.o["paste"]
              end,
            },
          },
          lualine_b = { { "b:gitsigns_head", icon = "" }, { "diff", source = get_git_status } },
          lualine_c = { "filename" },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { { "diagnostics", sources = { "nvim_lsp" } } },
          lualine_z = { "progress", { "location", icon = "" } },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { "filename" },
          lualine_x = { { "location", icon = "" } },
          lualine_y = {},
          lualine_z = {},
        },
      })
    end,
  },
  -- }}}
  -- Nvim-Tree provides a lua-based file-explorer {{{
  {
    "nvim-tree/nvim-tree.lua",
    init = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      vim.opt.termguicolors = true
    end,
    config = function()
      local api = require("nvim-tree.api")

      M = {}
      function M.print_node_path()
        local node = api.tree.get_node_under_cursor()
        print(node.absolute_path)
      end
      function M.on_attach(bufnr)
        api.config.mappings.default_on_attach(bufnr)
        -- Additional mappings
        local function opts(desc)
          return { desc = desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end
        vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
        vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))
        vim.keymap.set("n", "?", api.tree.toggle_help, opts("Help"))
        vim.keymap.set("n", "p", M.print_node_path, opts("Print"))
      end

      -- See project.nvim setup: https://github.com/ahmedkhalf/project.nvim#-features
      require("nvim-tree").setup({
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        update_focused_file = {
          enable = true,
          update_root = true,
        },
        -- Add settings
        on_attach = M.on_attach,
      })
    end,
  },
  -- }}}
  -- Peekaboo displays a preview window of register contents {{{
  "junegunn/vim-peekaboo",
  -- }}}
  -- Project provides "superior project management", but primarily cd'ing to a project root {{{
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup()
    end,
  },
  -- }}}
  -- Pounce is a motion plugin akin to Hop/Sneak/Lightspeed with fuzzy matching {{{
  {
    "rlane/pounce.nvim",
    priority = 0,
    config = function()
      vim.keymap.set("n", "s", ":Pounce<CR>")
      vim.keymap.set("n", "S", ":PounceRepeat<CR>")
    end,
  },
  -- }}}
  -- Startify is a fancy start page for Vim {{{
  "mhinz/vim-startify",
  -- }}}
  -- Telescope is an extensible fuzzy finder tool {{{
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/popup.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-ui-select.nvim",
    },
    priority = 10,
    config = function()
      local actions = require("telescope.actions")
      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
            },
          },
          file_ignore_patterns = {
            ".cache/.*",
            ".git/.*",
            "node_modules/.*",
            "%.pyc",
          },
          layout_strategy = "flex",
        },
        pickers = {
          find_files = {
            theme = "dropdown",
            previewer = false,
          },
        },
      })
      require("telescope").load_extension("ui-select")
    end,
  },
  -- }}}
  -- ToggleTerm provides better terminal integration {{{
  {
    "akinsho/toggleterm.nvim",
    config = function()
      require("toggleterm").setup({
        open_mapping = [[<C-\>]],
        close_on_exit = true,
        direction = "float",
        float_opts = {
          border = "curved",
        },
      })
    end,
  },
  -- }}}
  -- Vim-cool smartly toggles search highlighting automatically {{{
  "romainl/vim-cool",
  -- }}}
  -- Vim-OSCyank has vim use OSC52 to copy to the system clipboard {{{
  "ojroques/nvim-osc52",
  -- }}}
  -- VimWiki links docs into a personal wiki, inside vim {{{
  "vimwiki/vimwiki",
  -- }}}
  -- Which-Key for displaying a key-binding cheatsheet {{{
  "folke/which-key.nvim",
  -- }}}
}

-- Bootstrap Lazy (our plugin manager of choice)
function M.bootstrap()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      lazypath,
    })
  end
  vim.opt.rtp:prepend(lazypath)
end

function M.init()
  M.bootstrap()
  require("lazy").setup(M.configs, M.opts)
end

return M
-- vim: set foldmethod=marker foldlevel=0 :
