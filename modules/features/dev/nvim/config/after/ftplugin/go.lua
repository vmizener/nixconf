local utils = require("utils")

-- Golang prefers real tab characters
vim.bo["expandtab"] = false

-- Run gofmt on write
vim.api.nvim_create_augroup("GolangConfig", {})
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
    if vim.fn.executable("gofmt") == 1 then
      utils.reformat(":%!gofmt")
    end
  end,
  group = "GolangConfig",
})
