/*
  feat/dev/nvim

Provides Neovim.

Exposes:

- flake.homeModules."feat/dev/nvim":
  - Enables Neovim
*/
{withSystem, ...}: let
  moduleName = "feat/dev/nvim";
in {
  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    treefmtCfg = withSystem pkgs.stdenv.hostPlatform.system (
      {config, ...}: config.treefmt
    );
    defaultTreefmt = pkgs.writeShellScriptBin "treefmt" ''
      set -euo pipefail
      unset PRJ_ROOT
      exec ${treefmtCfg.package}/bin/treefmt \
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
        ++ [defaultTreefmt]
        ++ builtins.attrValues treefmtCfg.build.programs;
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
    mod."common/mime".add.editor."nvim.desktop" = 100;
    home.sessionVariables.EDITOR = lib.mkOverride 100 "nvim";
  };
}
