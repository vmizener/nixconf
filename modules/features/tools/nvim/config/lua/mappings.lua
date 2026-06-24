local M = {}
M.ALL = {
  "set_binds",
}

M.mapleader = " "
-- stylua: ignore start
M.lsp_binds = {
    {"n", "gD", function() vim.lsp.buf.declaration() end, "[LSP] Jump to the declaration of the symbol"},
    {"n", "gd", function() vim.lsp.buf.definition() end, "[LSP] Jump to the definition of the symbol"},
    {"n", "K", function() vim.lsp.buf.hover() end, "[LSP] Display information about the symbol in a floating window"},
    {"n", "<C-k>", function() vim.lsp.buf.signature_help() end, "[LSP] Display signature information about the symbol"},
    {"n", "gr", function() vim.lsp.buf.references() end, "[LSP] List all references of the symbol in the quickfix window"},
    {"n", "gi", function() vim.lsp.buf.implementation() end, "[LSP] List all implementations of the symbol in the quickfix window"},
    {"n", "gt", function() vim.lsp.buf.type_definition() end, "[LSP] Jump to the type definition of the symbol"},
    {"n", "<Leader>rn", function() vim.lsp.buf.rename() end, "[LSP] Rename the symbol"},
    {"n", "<Leader>j", function() vim.diagnostic.jump({count=1, float=true}) end, "[LSP] Jump to the next diagnostic message"},
    {"n", "<Leader>k", function() vim.diagnostic.jump({count=-1, float=true}) end, "[LSP] Jump to the previous diagnostic message"},
    {"n", "<Leader>f", function() vim.diagnostic.open_float() end, "[LSP] Show diagnostics in a floating window"},
    {"i", "<C-n>", function() vim.lsp.completion.get() end, "[LSP] Open auto-complete menu, or selects next completion option"},
    {"i", "<C-p>", function() vim.lsp.completion.get() end, "[LSP] Open auto-complete menu, or selects prev completion option"},
}
M.plugin_binds = {
    -- Comment
    -- (note that CTRL+/ is equivalent to C-_ in some terminals)
    {"n", "<C-/>", "<Plug>(comment_toggle_linewise_current)", "[Comment] Toggle commenting of current line"},
    {"v", "<C-/>", "<Plug>(comment_toggle_linewise_visual)", "[Comment] Toggle commenting of current lines"},
    {"n", "<C-_>", "<Plug>(comment_toggle_linewise_current)", "[Comment] Toggle commenting of current line"},
    {"v", "<C-_>", "<Plug>(comment_toggle_linewise_visual)", "[Comment] Toggle commenting of current lines"},
    -- SymbolsOutline
    {"n", "<Leader>ss", ":SymbolsOutline<CR>", "[SymbolsOutline] Toggle symbols outline pane"},
    -- IndentLinesToggle
    {"n", "<Leader>i", ":IndentLinesToggle<CR>", "[IndentLines] Toggle indentation guide"},
    -- Fugitive
    {"n", "<Leader>gd", ":Gdiffsplit!<CR>", "[Git] View diff in a split"},
    -- {"n", "<Leader>gD", "<C-w>h<C-w>c", "[Git]"},
    {"n", "<Leader>gs", ":G status<CR>", "[Git] View status"},
    -- Gitsigns
    {"n", "<Leader>gj", ":Gitsigns next_hunk<CR>", "[Git] Next hunk"},
    {"n", "<Leader>gk", ":Gitsigns prev_hunk<CR>", "[Git] Previous hunk"},
    -- Nvim-Tree
    {"n", "<Leader>t", ":NvimTreeToggle<CR>", "[NvimTree] Toggle file tree"},
    -- Telescope
    {"n", "<Leader>of", ":Telescope find_files hidden=true<CR>", "[Telescope] File browser (show hidden)"},
    {"n", "<Leader>oF", ":Telescope find_files cwd=~ hidden=true<CR>", "[Telescope] File browser (from $HOME)"},
    {"n", "<Leader>og", ":Telescope live_grep<CR>", "[Telescope] Live grep"},
    {"n", "<Leader>ob", ":Telescope buffers<CR>", "[Telescope] Buffers"},
    {"n", "<Leader>oh", ":Telescope help_tags<CR>", "[Telescope] Help tags"},

    {"n", "<Leader>od", ":Telescope diagnostics<CR>", "[Telescope] Diagnostics"},
    {"n", "<Leader>ca", ":lua vim.lsp.buf.code_action()<CR>", "[Telescope] Code actions"},
    {"v", "<Leader>ca", ":lua vim.lsp.buf.code_action()<CR>", "[Telescope] Code actions"},
    -- WhichKey
    {"n", "<Leader>?", ":WhichKey<CR>", "[WhichKey] Open WhichKey"},
}
M.primary_binds = {
  -- Editor Controls {{{
    -- Get to normal mode with `jk` or `<Space>`
    {"i", "jk", "<Esc>", ""},      -- Escape insert mode
    {"v", "<Space>", "<Esc>", ""}, -- Escape visual mode with <Space>
    -- Navigate wrapped lines
    {"n", "j", "gj", ""},
    {"n", "k", "gk", ""},
    -- Indentation with tab key
    {"n", "<Tab>", ">>_", "Indent current line"},
    {"n", "<S-Tab>", "<<", "De-indent current line"},
    {"v", "<Tab>", ">gv", "Indent current line"},
    {"v", "<S-Tab>", "<gv", "De-indent current line"},
    -- Quickly close quickfix/loclist windows
    {"n", "QQ", ":cclose | lclose<CR>", "Close quickfix/loclist"},
  -- }}}

  -- Editor Behavior and Appearance {{{
    -- Center view on search results
    {"n", "n", "nzz", "Focus next search result"},
    {"n", "N", "Nzz", "Focus previous search result"},
    -- Toggle line wrap
    {"n", "<Leader>w", ":set wrap! wrap?<CR>", "Toggle line wrap"},
    -- Toggle invisible characters
    {"n", "<Leader>I", ":set list! list?<CR>", "Toggle invisible characters"},
    -- Toggle spell check mode
    {"n", "<F3>", ":set spell! spell?<CR>", "Toggle spell check"},
    {"v", "<F3>", "<ESC>:set spell! spell?<CR>gv", "Toggle spell check"},
    -- Toggle folding
    {"n", "z<Space>", "za", "Toggle folding"},
    {"v", "z<Space>", "za", "Toggle folding"},
    -- Use system clipboard
    {"x", "<Leader>y", '"+y', "Yank to system clipboard"},
    {"n", "<Leader>p", '"+p', "Paste from system clipboard"},
    {"v", "<Leader>p", '"+p', "Paste from system clipboard"},
  -- }}}

  -- Buffer Management {{{
    {"n", "<Leader>bp", ":bprev<CR>", ""},
    {"n", "<Leader>bn", ":bnext<CR>", ""},
    {"n", "<Leader>bb", ":b#<CR>", ""},
    {"n", "<Leader>bd", ":lclose|bprev|bd #<CR>", ""},
    {"n", "<Leader>bk", ":lclose|bprev|bd! #<CR>", ""},
  -- }}}

  -- File Management {{{
    -- Open config
    {"n", "<Leader>ec", ":e $MYVIMRC<CR>", "Open config"},
    -- Source config
    {"n", "<Leader>sc", ":source $MYVIMRC<CR>", "Source config"},
  -- }}}

  -- Mouse Scroll Behavior {{{
    -- (Requires "mouse=a" option)
    --           Scroll Wheel = Up/Down 4 lines
    --   Shift + Scroll Wheel = Up/Down 1 page
    -- Control + Scroll Wheel = Up/Down half page
    --    Meta + Scroll Wheel = Up/Down 1 line
    {"n", "<ScrollWheelUp>",     "4<C-Y>",      "Scroll 4 lines up"},
    {"n", "<ScrollWheelDown>",   "4<C-E>",      "Scroll 4 lines down"},
    {"n", "<S-ScrollWheelUp>",   "<C-B>",       "Scroll 1 page up"},
    {"n", "<S-ScrollWheelDown>", "<C-F>",       "Scroll 1 page down"},
    {"n", "<C-ScrollWheelUp>",   "<C-U>",       "Scroll half page up"},
    {"n", "<C-ScrollWheelDown>", "<C-D>",       "Scroll half page down"},
    {"n", "<M-ScrollWheelUp>",   "<C-Y>",       "Scroll 1 line up"},
    {"n", "<M-ScrollWheelDown>", "<C-E>",       "Scroll 1 line down"},

    {"i", "<ScrollWheelUp>",     "<C-O>4<C-Y>", "Scroll 4 lines up"},
    {"i", "<ScrollWheelDown>",   "<C-O>4<C-E>", "Scroll 4 lines down"},
    {"i", "<S-ScrollWheelUp>",   "<C-O><C-B>",  "Scroll 1 page up"},
    {"i", "<S-ScrollWheelDown>", "<C-O><C-F>",  "Scroll 1 page down"},
    {"i", "<C-ScrollWheelUp>",   "<C-O><C-U>",  "Scroll half page up"},
    {"i", "<C-ScrollWheelDown>", "<C-O><C-D>",  "Scroll half page down"},
    {"i", "<M-ScrollWheelUp>",   "<C-O><C-Y>",  "Scroll 1 line up"},
    {"i", "<M-ScrollWheelDown>", "<C-O><C-E>",  "Scroll 1 line down"},
  -- }}}
}
-- stylua: ignore end

function M.set_binds(binds, opts)
  local utils = require("utils")
  utils.set_default_map_opts(opts)
  for _, bindconfig in ipairs(binds) do
    utils.map(unpack(bindconfig))
  end
end

function M.lsp_attach(ev)
  local opts = { noremap = true, silent = true, buffer = ev.buf }
  M.set_binds(M.lsp_binds, opts)
end

function M.init()
  vim.g["mapleader"] = M.mapleader
  local opts = { noremap = true, silent = true }
  M.set_binds(M.primary_binds, opts)
  M.set_binds(M.plugin_binds, opts)
end

return M
