local utils = require("utils")

vim.api.nvim_create_augroup("PythonConfig", {})
-- Set style settings if necessary
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.py",
  callback = function()
    -- Use pyformat settings if we're using that
    if vim.fn.executable("pyformat") == 1 then
      local options = {
        shiftwidth = 2,
        softtabstop = 2,
        tabstop = 2,
      }
      for k, v in pairs(options) do
        vim.o[k] = v
      end
    end
  end,
  group = "PythonConfig",
})

-- Autoformat on write
if vim.fn.executable("pyformat") == 1 then
  -- Use pyformat if present
  vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*.py",
    callback = function()
      utils.reformat(":%! pyformat")
    end,
    group = "PythonConfig",
  })
elseif vim.fn.executable("black") == 1 then
  -- Fallback on black
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.py",
    callback = function()
      utils.reformat(":!black %")
    end,
    group = "PythonConfig",
  })
else
  vim.api.nvim_echo({ { "Missing python formatter!", "WarningMsg" } }, true, {})
end
