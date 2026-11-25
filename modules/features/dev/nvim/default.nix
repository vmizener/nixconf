/*
  feat/dev/nvim

Provides Neovim with LSP servers, Treesitter grammars, and an optional
standalone fallback `treefmt` formatter.

Exposes:

- flake.homeModules."common/options" (options.mod."feat/dev/nvim")
- flake.homeModules."feat/dev/nvim":
  - Enables Neovim and registers it as the preferred editor handler.
*/
{inputs, ...}: let
  moduleName = "feat/dev/nvim";
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      treefmt = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to bundle a standalone fallback `treefmt` wrapper and formatters with Neovim.";
        };
        config = lib.mkOption {
          type = lib.types.deferredModule;
          default = {};
          description = "Additional `treefmt-nix` configuration merged into Neovim's fallback `treefmt` instance.";
        };
      };
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    treefmtCfg =
      (inputs.treefmt-nix.lib.evalModule pkgs {
        imports = [cfg.treefmt.config];
        programs = {
          alejandra.enable = lib.mkDefault true;
          black.enable = lib.mkDefault true;
          shfmt.enable = lib.mkDefault true;
          stylua = {
            enable = lib.mkDefault true;
            settings = {
              indent_type = lib.mkDefault "Spaces";
              indent_width = lib.mkDefault 2;
            };
          };
        };
      }).config;
    defaultTreefmt = pkgs.writeShellScriptBin "treefmt" ''
      set -euo pipefail
      unset PRJ_ROOT
      exec ${lib.getExe treefmtCfg.package} \
        --config-file=${treefmtCfg.build.configFile} \
        --tree-root="''${TREEFMT_TREE_ROOT:-$PWD}" \
        "$@"
    '';
    tsParsers = pkgs.symlinkJoin {
      name = "treesitter-parsers";
      paths = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
    };
  in {
    mod.meta.imported = [moduleName];
    programs.neovim = {
      enable = true;
      sideloadInitLua = true;
      extraPackages =
        (with pkgs; [
          tree-sitter

          fd
          go
          lua-language-server
          nixd
          pyright
          ripgrep
        ])
        ++ lib.optionals cfg.treefmt.enable (
          [defaultTreefmt] ++ builtins.attrValues treefmtCfg.build.programs
        );
      extraWrapperArgs = [
        # pass path via global so Lazy preserves it across rtp reset (before FileType)
        "--add-flags"
        "--cmd 'lua vim.g.nix_ts_parsers = \"${tsParsers}\"'"
      ];
      withNodeJs = true;
      withPython3 = true;
      withRuby = true;
    };
    xdg.configFile."nvim".source = config.mod.meta.link ./config;

    # Mark neovim as preferred editor
    mod."common/handlers".add.editor.nvim = {
      priority = 100;
      label = "Neovim";
      desktop = "nvim.desktop";
      cmd = ["nvim"];
    };
    home.sessionVariables.EDITOR = lib.mkOverride 100 "nvim";
  };
}
