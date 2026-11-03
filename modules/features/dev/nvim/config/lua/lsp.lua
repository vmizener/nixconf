local M = {}

M.ALL = {
  "enable_config",
}
M.CONFIGS = {
  -- Lua (lua_ls) {{{
  lua_ls = {
    on_init = function(client)
      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if
          (path ~= vim.fn.stdpath("config"))
          and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc"))
        then
          return
        end
      end

      client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
        diagnostics = { globals = { "vim" } },
        runtime = {
          -- Tell the language server which version of Lua you're using (most
          -- likely LuaJIT in the case of Neovim)
          version = "LuaJIT",
          -- Tell the language server how to find Lua modules same way as Neovim
          -- (see `:h lua-module-load`)
          path = {
            "lua/?.lua",
            "lua/?/init.lua",
          },
        },
        -- Make the server aware of Neovim runtime files
        workspace = {
          checkThirdParty = false,
          library = {
            vim.env.VIMRUNTIME, -- Neovim runtime files
            vim.fn.stdpath("config"), -- User config files
            "${3rd}/luv/library", -- LibUV C library (adds `vim.uv`)
            -- Depending on the usage, you might want to add additional paths
            -- here.
            -- '${3rd}/busted/library',
          },
          -- Or pull in all of 'runtimepath'.
          -- NOTE: this is a lot slower and will cause issues when working on
          -- your own configuration.
          -- See https://github.com/neovim/nvim-lspconfig/issues/3189
          -- library = vim.api.nvim_get_runtime_file('', true),
        },
      })
    end,
    settings = {},
  },
  -- }}}
  -- Nix (nixd) {{{
  nixd = {
    cmd = { "nixd" },
    filetypes = { "nix" },
    root_markers = { "flake.nix", ".git" },
    before_init = function(_, config)
      local xdg_config = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
      local candidates = {}
      local function add_candidate(dir)
        if dir and dir ~= "" then
          table.insert(candidates, vim.fn.expand(dir))
        end
      end

      add_candidate(vim.env.NH_FLAKE)
      add_candidate(vim.env.NH_OS_FLAKE)
      add_candidate(vim.env.NH_HOME_FLAKE)
      add_candidate("/etc/nixos")
      add_candidate(xdg_config .. "/home-manager")

      local flake_path = nil
      for _, dir in ipairs(candidates) do
        if vim.uv.fs_stat(dir .. "/flake.nix") then
          flake_path = vim.uv.fs_realpath(dir)
          if flake_path then
            break
          end
        end
      end

      if not flake_path then
        vim.notify(
          "No flake.nix found via NH_FLAKE, /etc/nixos, or " .. xdg_config .. "/home-manager.",
          vim.log.levels.WARN
        )
        return
      end

      local function expr(type)
        return table.concat({
          "let",
          '  flake = builtins.getFlake "' .. flake_path .. '";',
          "  target = (",
          "    flake.nixdOptions." .. type,
          "    or flake.inputs.nixconf.nixdOptions." .. type,
          "    or null",
          "  );",
          "in",
          "  if target != null then target.options else {}",
        }, "\n")
      end

      config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
        nixd = {
          options = {
            home_manager = { expr = expr("home") },
            nixos = { expr = expr("nixos") },
            flake_parts = {
              expr = table.concat({
                "let",
                '  flake = builtins.getFlake "' .. flake_path .. '";',
                "in",
                "  flake.debug.options",
              }, "\n"),
            },
          },
        },
      })
    end,
    settings = {
      nixd = {
        nixpkgs = {
          expr = "import <nixpkgs> { }",
        },
      },
    },
  },
  -- }}}
  -- Python (pyright) {{{
  pyright = {
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = "openFilesOnly",
        },
      },
    },
  },
  -- }}}
}

function M.enable_config(name, config)
  vim.lsp.config(name, config)
  vim.lsp.enable(name)
end

function M.init()
  -- Enable global settings
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  vim.lsp.config("*", { capabilities = capabilities })
  vim.diagnostic.config({ virtual_lines = true })
  -- Enable per-server settings
  for name, config in pairs(M.CONFIGS) do
    M.enable_config(name, config)
  end
  -- Add autocmd to trigger settings when a server attaches
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
      -- Bind LSP mappings
      require("mappings").lsp_attach(ev)
      -- Enable completion if supported
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client:supports_method("textDocument/completion") then
        vim.opt.completeopt = { "menuone", "preview", "noselect", "fuzzy" }
        vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
      end
    end,
  })
  -- Add autocmd to close preview window after completion
  vim.api.nvim_create_autocmd("CompleteDone", { command = "pclose" })
end

return M
-- vim: set foldmethod=marker foldlevel=0 :
