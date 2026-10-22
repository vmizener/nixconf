local utils = require("utils")

local function use_pyformat(bufnr)
  return vim.fn.executable("pyformat") == 1 and vim.fs.root(bufnr or 0, ".citc") ~= nil
end

vim.api.nvim_create_augroup("PythonConfig", {})
-- Set style settings if necessary
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.py",
  callback = function(ev)
    -- Use pyformat settings inside CitC workspaces
    if use_pyformat(ev.buf) then
      vim.bo[ev.buf].shiftwidth = 2
      vim.bo[ev.buf].softtabstop = 2
      vim.bo[ev.buf].tabstop = 2
    end
  end,
  group = "PythonConfig",
})

-- Autoformat on write
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.py",
  callback = function(ev)
    if use_pyformat(ev.buf) then
      utils.reformat(":%! pyformat")
    else
      utils.reformat()
    end
  end,
  group = "PythonConfig",
})
