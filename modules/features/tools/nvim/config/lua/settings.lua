local M = {}
M.ALL = {
  "set_options",
  "set_autocommands",
}

function M.set_options()
  -- stylua: ignore start
  vim.opt.autoindent = true       -- Automatic indentation
  vim.opt.smartindent = true      -- Detect language-based indentation levels
  vim.opt.cmdheight = 0           -- Hide the command line by default
  vim.opt.background = 'dark'     -- Use dark colorscheme for background
  vim.opt.breakindent = true      -- Indent line-breaks to align with code
  vim.opt.confirm = true          -- Confirm quit if there're unsaved changes
  vim.opt.expandtab = true        -- Fill tabs with spaces
  vim.opt.hidden = true           -- Don't require writing buffers before hiding them
  vim.opt.hlsearch = true         -- Highlight search results
  vim.opt.incsearch = true        -- Do incremental search
  vim.opt.ignorecase = true       -- Do case-insensitive search ...
  vim.opt.smartcase = true        -- ... unless capital letters are used
  vim.opt.history = 500           -- MOAR history
  vim.opt.modeline = true         -- MOAR modeline
  vim.opt.mouse = 'a'             -- MOAR mouse
  vim.opt.undolevels = 500        -- MOAR undo
  vim.opt.backup = false          -- No .bak files thank you
  vim.opt.swapfile = false        -- No swap file thank you
  vim.opt.joinspaces = false      -- No extra space after '.' when joining lines
  vim.opt.wrap = false            -- No line wrap please
  vim.opt.writebackup = false     -- No .bak files even before writing
  vim.opt.number = true           -- Show absolute line numbers
  vim.opt.relativenumber = true   -- Show relative line numbers
  vim.opt.scrolloff = 10          -- Leave lines above/below cursor
  vim.opt.shiftwidth = 4          -- Set indentation depth to 4 columns
  vim.opt.sidescroll = 1          -- Ensure smooth side-scrolling
  vim.opt.sidescrolloff = 1       -- Don't select edge characters while side-scrolling
  vim.opt.softtabstop = 4         -- Backspace over 4-space tabs together
  vim.opt.splitbelow = true       -- Always split below current buffer
  vim.opt.splitright = true       -- Always split right of current buffer
  vim.opt.tabstop = 4             -- Set tabular length to 4 columns
  vim.opt.termguicolors = true    -- Enable RGB color in the TUI
  vim.opt.textwidth = 0           -- Do not automatically wrap text when pasting long lines
  vim.opt.timeoutlen = 250        -- Use less timeout
  vim.opt.ttimeoutlen = 10        -- Use less keycode timeout
  vim.opt.updatetime = 500        -- Check file status every half second
  vim.opt.virtualedit = 'block'   -- Allow selecting over non-existant characters in visual block mode
  vim.opt.winblend = 20           -- Add transparency to floating windows
  vim.opt.winborder = 'rounded'   -- Use rounded floating window borders
  -- stylua: ignore end

  -- Use UTF-8 encoding
  vim.opt.encoding = "utf-8"
  -- Use vertical diff splits by default
  vim.opt.diffopt = { "internal", "filler", "vertical" }
  -- View sessions should save appropriate things (not local options!)
  vim.opt.viewoptions = { "cursor", "folds", "slash", "unix" }
  -- See ALL the characters
  vim.opt.list = true
  vim.opt.listchars = { tab = "→ ", nbsp = "␣", trail = "·", extends = "⟩", precedes = "⟨" }
  vim.opt.showbreak = "↪ "
  -- Set terminal title
  vim.opt.title = true
  vim.opt.titlelen = 40
  vim.opt.titlestring = "%f%=%<(%l/%L:%P)" -- See "statusline" help for item defs
  -- Configure folding
  vim.opt.foldlevelstart = 99 -- Open files with open folds
  vim.opt.foldmethod = "expr"
  vim.opt.foldexpr = "nvim_treesitter#foldexpr()" -- Use treesitter for folding rules
end

function M.set_autocommands()
  local augroup = vim.api.nvim_create_augroup
  local autocmd = vim.api.nvim_create_autocmd

  -- Automatically show absolute numbering while in insert mode
  augroup("InsertRelNum", { clear = true })
  autocmd("InsertEnter", { command = "set norelativenumber", group = "InsertRelNum" })
  autocmd("InsertLeave", { command = "set relativenumber", group = "InsertRelNum" })

  -- Highlight characters in column 90 and columns 120+
  augroup("ColorCol", { clear = true })
  autocmd("ColorScheme", {
    command = "highlight ColorColumn ctermbg=darkred guibg=darkred",
    group = "ColorCol",
  })
  autocmd("ColorScheme", {
    command = "match ColorColumn /\\%>89v.*\\%<91v/",
    group = "ColorCol",
  })
  autocmd("ColorScheme", {
    command = "2match ColorColumn /\\%>120v/",
    group = "ColorCol",
  })
end

function M.init()
  for _, method in ipairs(M.ALL) do
    M[method]()
  end
end

return M
