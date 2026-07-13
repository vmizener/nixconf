/*
  feat/tools/nvim

Provides Neovim.

Exposes:

- flake.homeModules."feat/tools/nvim":
  - Enables Neovim
*/
{
  flake.homeModules."feat/tools/nvim" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfgPath = config.flakePath + "/modules/features/tools/nvim/config";
    tsParsers = pkgs.symlinkJoin {
      name = "treesitter-parsers";
      # paths = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
      paths =
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.bash
          p.c
          p.cpp
          p.csv
          p.go
          p.html
          p.jq
          p.json
          p.json5
          p.kdl
          p.latex
          p.lua
          p.markdown
          p.nix
          p.python
          p.regex
          p.scss
          p.tmux
          p.vim
          p.vimdoc
          p.yaml
          p.xml
          p.zsh
        ])).dependencies;
    };
  in {
    features.tools = ["nvim"];
    programs.neovim = {
      enable = true;
      sideloadInitLua = true;
      extraPackages = with pkgs; [
        tree-sitter

        black
        fd
        go
        lua-language-server
        nixd
        nixfmt
        pyright
        ripgrep
        stylua
      ];
      extraWrapperArgs = [
        # uses autocmd rather than direct addition to avoid Lazy removing it on init
        "--add-flags"
        "--cmd 'autocmd VimEnter * lua vim.opt.runtimepath:append(\"${tsParsers}\")'"
      ];
      withNodeJs = true;
      withPython3 = true;
      withRuby = true;
    };
    xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink cfgPath;

    # Mark neovim as preferred editor
    features.system.mime.categories.editors = lib.mkIf config.features.system.mime.enable (lib.mkOrder 100 ["nvim.desktop"]);
    home.sessionVariables.EDITOR = lib.mkOverride 100 "nvim";
  };
}
