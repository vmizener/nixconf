/*
  feat/tools/nvim

Provides Neovim.

Exposes:

- flake.homeModules."feat/tools/nvim":
  - Enables Neovim
*/
{withSystem, ...}: let
  moduleName = "feat/tools/nvim";
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
    mod.imported = [moduleName];
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
        # uses autocmd rather than direct addition to avoid Lazy removing it on init
        "--add-flags"
        "--cmd 'autocmd VimEnter * lua vim.opt.runtimepath:append(\"${tsParsers}\")'"
      ];
      withNodeJs = true;
      withPython3 = true;
      withRuby = true;
    };
    xdg.configFile."nvim".source = config.mod.nixconf.link ./config;

    # Mark neovim as preferred editor
    mod."feat/system/mime".add.editor."nvim.desktop" = 100;
    home.sessionVariables.EDITOR = lib.mkOverride 100 "nvim";
  };
}
