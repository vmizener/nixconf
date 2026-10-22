local utils = require("utils")

-- Indent with 2 spaces
vim.bo["shiftwidth"] = 2
vim.bo["softtabstop"] = 2
vim.bo["tabstop"] = 2

-- Autoformat on write
vim.api.nvim_create_augroup("ShConfig", {})
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.sh", "*.bash", ".envrc", "*.envrc.*" },
  callback = function()
    utils.reformat()
  end,
  group = "ShConfig",
})
