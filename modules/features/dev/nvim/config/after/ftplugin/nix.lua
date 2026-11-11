local utils = require("utils")

-- Indent with 2 spaces
vim.bo["shiftwidth"] = 2
vim.bo["softtabstop"] = 2
vim.bo["tabstop"] = 2

local bufnr = vim.api.nvim_get_current_buf()
local group = vim.api.nvim_create_augroup("NixConfig", { clear = false })
vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })

-- Autoformat on write
vim.api.nvim_create_autocmd("BufWritePre", {
  buffer = bufnr,
  callback = function()
    utils.reformat()
  end,
  group = group,
})

-- Temporarily include `/`, `:`, and `@` in `iskeyword` while the completion
-- popup is open so typing e.g. `feat/vm` filters candidates instead of exiting
-- completion mode (ASCII codes / `@-@` avoid Vim's `@` = isalpha meaning).
local saved_isk = nil
local function add_completion_isk()
  if not saved_isk then
    saved_isk = vim.bo[bufnr].iskeyword
    vim.bo[bufnr].iskeyword = saved_isk .. ",47,58,@-@"
  end
end
local function restore_isk()
  if saved_isk then
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.bo[bufnr].iskeyword = saved_isk
    end
    saved_isk = nil
  end
end

vim.api.nvim_create_autocmd("CompleteChanged", {
  buffer = bufnr,
  callback = add_completion_isk,
  group = group,
})
vim.api.nvim_create_autocmd("InsertLeave", {
  buffer = bufnr,
  callback = restore_isk,
  group = group,
})

-- Autocompletion of options/attrset keys may need to be quoted
vim.api.nvim_create_autocmd("CompleteDone", {
  buffer = bufnr,
  callback = function()
    restore_isk()

    local function needs_nix_quotes(name)
      -- Skip already-quoted strings, path literals, and multi-token snippets.
      if name:find('^"') or name:find("^%.?%.?/") or name:find("[%s=]") then
        return false
      end
      -- Valid unquoted Nix identifiers match `[A-Za-z_][A-Za-z0-9_'-]*`.
      return not name:match("^[A-Za-z_][A-Za-z0-9_'%-]*$")
    end

    local item = vim.v.completed_item
    local word = item and item.word
    if (not word) or (word == "") or (not needs_nix_quotes(word)) then
      return
    end
    if item.kind == "File" or item.kind == "Folder" then
      return
    end

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1 -- nvim_buf_get_lines() uses zero-based rows

    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if not line then
      return
    end

    local start_col = col - #word
    if start_col < 0 then
      return
    end

    -- Make sure the text immediately before the cursor is the completed word.
    if line:sub(start_col + 1, col) ~= word then
      return
    end

    -- Quote when completing after an attrpath dot (`mod.feat/vm`) or at the
    -- start of an attrset binding (`mod = { feat/vm = ...; }`), skipping if
    -- already inside quotes (`nixosModules."feat/vm"`).
    local prefix = line:sub(1, start_col)
    local after_dot = prefix:sub(-1) == "." and prefix:sub(-2) ~= ".."
    local at_key_start = prefix:match("^%s*$") ~= nil or prefix:match("[{;]%s*$") ~= nil
    if not (after_dot or at_key_start) then
      return
    end

    vim.api.nvim_buf_set_text(bufnr, row, start_col, row, col, { '"' .. word .. '"' })

    -- Move the cursor past the two added quote characters.
    vim.api.nvim_win_set_cursor(0, { row + 1, col + 2 })
  end,
  group = group,
})
