local utils = require("utils")

-- Indent with 2 spaces
vim.bo["shiftwidth"] = 2
vim.bo["softtabstop"] = 2
vim.bo["tabstop"] = 2

vim.api.nvim_create_augroup("LuaConfig", {})
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.lua",
  callback = function()
    -- Use stylua if present
    if vim.fn.executable("stylua") == 1 then
      utils.reformat(":!stylua --indent-type Spaces --indent-width 2 %")
    else
      vim.api.nvim_echo({ { "Missing lua formatter!", "WarningMsg" } }, true, {})
    end
  end,
  group = "LuaConfig",
})
