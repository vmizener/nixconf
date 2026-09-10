/*
  feat/tools/nvim

Provides Neovim.

Exposes:

- flake.homeModules."feat/tools/nvim":
  - Enables Neovim
*/
let
  moduleName = "feat/tools/nvim";
in {
  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    tsParsers = pkgs.symlinkJoin {
      name = "treesitter-parsers";
      paths = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
    };
  in {
    mod.imported = [moduleName];
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
    xdg.configFile."nvim".source = config.mod.nixconf.link ./config;

    # Mark neovim as preferred editor
    mod."feat/system/mime".add.editor."nvim.desktop" = 100;
    home.sessionVariables.EDITOR = lib.mkOverride 100 "nvim";
  };
}
