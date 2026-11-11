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
      -- 1. Collect ordered, deduplicated candidate flake directories.
      -- Resolve symlinks via `fs_realpath` because `builtins.getFlake` rejects
      -- symlinked flake roots (and to deduplicate e.g. ~/.config/home-manager -> nixconf).
      local xdg_config = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
      local candidates = {}
      local seen = {}
      local function add_candidate(dir)
        if dir and dir ~= "" then
          local expanded = vim.fn.expand(dir)
          if vim.uv.fs_stat(expanded .. "/flake.nix") then
            local real = vim.uv.fs_realpath(expanded)
            if real and not seen[real] then
              seen[real] = true
              table.insert(candidates, vim.json.encode(real))
            end
          end
        end
      end

      -- Prefer the active workspace's flake so local option edits in `nixconf`
      -- take effect immediately, while keeping system/HM flakes as fallbacks
      -- when editing standalone `.nix` files or unrelated project flakes.
      add_candidate(config.root_dir)
      add_candidate(vim.env.NH_FLAKE)
      add_candidate(vim.env.NH_OS_FLAKE)
      add_candidate(vim.env.NH_HOME_FLAKE)
      add_candidate("/etc/nixos")
      add_candidate(xdg_config .. "/home-manager")

      if #candidates == 0 then
        vim.notify(
          "No flake.nix found via root_dir, NH_FLAKE, /etc/nixos, or " .. xdg_config .. "/home-manager.",
          vim.log.levels.WARN
        )
        return
      end

      -- 2. Build a Nix expression that lazily probes each candidate flake in
      -- order (`map builtins.getFlake` creates thunks; `foldl'` stops forcing
      -- candidates once `selector` returns a non-null option set).
      local flake_paths = "[ " .. table.concat(candidates, " ") .. " ]"
      local function pick_expr(selector)
        return table.concat({
          "let",
          "  flakes = map builtins.getFlake " .. flake_paths .. ";",
          "  pick = f: builtins.foldl' (acc: flake: if acc != null then acc else f flake) null flakes;",
          "  res = pick (" .. selector .. ");",
          "in",
          "  if res != null then res else {}",
        }, "\n")
      end

      -- Look up dummy option evaluations from `modules/nixd.nix` directly on the
      -- flake, or via `inputs.nixconf` for downstream flakes that consume `nixconf`.
      local function nixd_expr(type)
        return pick_expr(
          "flake: let target = flake.nixdOptions."
            .. type
            .. " or flake.inputs.nixconf.nixdOptions."
            .. type
            .. " or null; in if target != null then target.options else null"
        )
      end

      -- 3. Inject option providers by mutating `config.settings.nixd` in place.
      -- Neovim's `Client.create()` binds `client.settings = config.settings`
      -- *before* `before_init` runs, and `workspace/configuration` reads
      -- `client.settings`—so reassigning `config.settings = ...` would strand
      -- `client.settings` on the initial table below.
      config.settings.nixd = vim.tbl_deep_extend("force", config.settings.nixd or {}, {
        options = {
          home_manager = { expr = nixd_expr("home") },
          nixos = { expr = nixd_expr("nixos") },
          -- Top-level flake-parts options (`flake.*`, `systems`, `inventory.*`),
          -- exposed when `debug = true` in `modules/parts.nix`.
          flake_parts = {
            expr = pick_expr("flake: flake.debug.options or flake.inputs.nixconf.debug.options or null"),
          },
          -- `perSystem` submodule options (`packages`, `devShells`, `treefmt`,
          -- `pre-commit`); `currentSystem` works in nixd's impure eval, with
          -- `allSystems.${sys}` as a pure-eval fallback.
          per_system = {
            expr = pick_expr(
              'flake: let sys = builtins.currentSystem or "x86_64-linux"; in '
                .. "flake.currentSystem.options or flake.allSystems.${sys}.options "
                .. "or flake.inputs.nixconf.currentSystem.options or flake.inputs.nixconf.allSystems.${sys}.options or null"
            ),
          },
        },
      })
    end,
    -- Keep `settings` non-nil so `client.settings` and `config.settings` share
    -- the same table reference when `before_init` mutates `config.settings.nixd`.
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
