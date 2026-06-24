local M = {}
M.ALL = {
  "set_default_map_opts",
  "map",
  "info",
  "warn",
  "err",
  "sudo_exec",
  "sudo_write",
  "reformat",
}

-- Keymapping
function M.set_default_map_opts(opts)
  M._map_opts = opts
end
function M.map(mode, lhs, rhs, desc, t)
  if t == nil then
    t = M._map_opts or {}
  end
  t["desc"] = desc
  vim.keymap.set(mode, lhs, rhs, t)
end

-- Logging
local function echo_multiline(msg)
  for _, s in ipairs(vim.fn.split(msg, "\n")) do
    vim.cmd("echom '" .. s:gsub("'", "''") .. "'")
  end
end

function M.info(msg)
  vim.cmd("echohl Directory")
  echo_multiline(msg)
  vim.cmd("echohl None")
end

function M.warn(msg)
  vim.cmd("echohl WarningMsg")
  echo_multiline(msg)
  vim.cmd("echohl None")
end

function M.err(msg)
  vim.cmd("echohl ErrorMsg")
  echo_multiline(msg)
  vim.cmd("echohl None")
end

-- Sudo commands
function M.sudo_exec(cmd, print_output)
  vim.fn.inputsave()
  local password = vim.fn.inputsecret("Password: ")
  vim.fn.inputrestore()
  if not password or #password == 0 then
    M.warn("Invalid password, sudo aborted")
    return false
  end
  local out = vim.fn.system(string.format("sudo -p '' -S %s", cmd), password)
  if vim.v.shell_error ~= 0 then
    print("\r\n")
    M.err(out)
    return false
  end
  if print_output then
    print("\r\n", out)
  end
  return true
end

function M.sudo_write(tmpfile, filepath)
  if not tmpfile then
    tmpfile = vim.fn.tempname()
  end
  if not filepath then
    filepath = vim.fn.expand("%")
  end
  if not filepath or #filepath == 0 then
    M.err("E32: No file name")
    return
  end
  -- `bs=1048576` is equivalent to `bs=1M` for GNU dd or `bs=1m` for BSD dd
  -- Both `bs=1M` and `bs=1m` are non-POSIX
  local cmd = string.format("dd if=%s of=%s bs=1048576", vim.fn.shellescape(tmpfile), vim.fn.shellescape(filepath))
  -- no need to check error as this fails the entire function
  -- vim.api.nvim_exec(string.format("write! %s", tmpfile), true)
  vim.cmd("write! " .. tmpfile)
  if M.sudo_exec(cmd) then
    M.info(string.format('\n"%s" written', filepath))
    vim.cmd("e!")
  end
  vim.fn.delete(tmpfile)
end

--- Reformat the current buffer using the given external command.
--- @param exec_str string Command to execute
function M.reformat(exec_str)
  local view = vim.fn.winsaveview()
  vim.cmd('silent execute "' .. exec_str .. '"')
  if vim.v["shell_error"] > 0 then
    -- If there are errors, put them in the quicklist and undo the formatting
    vim.cmd("cexpr getline(1, '$')->map({ idx, val -> val->substitute('<standard input>', expand('%'), '') })")
    vim.cmd("silent undo")
    vim.cmd("cwindow")
  end
  vim.fn.winrestview(view)
end

return M
