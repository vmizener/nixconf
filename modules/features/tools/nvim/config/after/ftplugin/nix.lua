-- Indent with 2 spaces
vim.bo["shiftwidth"] = 2
vim.bo["softtabstop"] = 2
vim.bo["tabstop"] = 2

-- Autocompletion of options may need to be quoted
vim.api.nvim_create_augroup("NixConfig", {})
vim.api.nvim_create_autocmd("CompleteDone", {
  callback = function()
    local function needs_nix_quotes(name)
      -- word contains a "/"
      return name:find("/") ~= nil
    end

    local item = vim.v.completed_item
    local word = item and item.word
    if (not word) or (word == "") or (not needs_nix_quotes(word)) then
      -- no special handling needed
      return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1 -- nvim_buf_get_lines() uses zero-based rows

    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if not line then
      return
    end

    local start_col = col - #word
    if start_col < 1 then
      return
    end

    -- Make sure the completed component follows a dot:
    --     flake.my/option
    --           ^
    if line:sub(start_col, start_col) ~= "." then
      return
    end

    -- Make sure the text immediately before the cursor is the completed word.
    if line:sub(start_col + 1, col) ~= word then
      return
    end

    vim.api.nvim_buf_set_text(bufnr, row, start_col, row, col, { '"' .. word .. '"' })

    -- Move the cursor past the two added quote characters.
    vim.api.nvim_win_set_cursor(0, { row + 1, col + 2 })
  end,
  group = "NixConfig",
})
