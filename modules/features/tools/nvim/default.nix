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
      paths = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
    };
  in {
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
    home.sessionVariables.EDITOR = lib.mkOverride 100 "nvim";
    xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink cfgPath;
  };
}
