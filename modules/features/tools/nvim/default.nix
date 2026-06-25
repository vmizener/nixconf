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
  }: {
    programs.neovim = {
      enable = true;
      sideloadInitLua = true;
      extraPackages = with pkgs; [
        black
        fd
        go
        lua-language-server
        nixd
        nixfmt
        pyright
        ripgrep
        stylua
        tree-sitter
      ];
      withNodeJs = true;
      withPython3 = true;
      withRuby = true;
    };
    home.sessionVariables.EDITOR = lib.mkOverride 100 "nvim";
    xdg.configFile."nvim".source = let
      cfgPath = config.flakePath + "/modules/features/tools/nvim/config";
    in
      config.lib.file.mkOutOfStoreSymlink cfgPath;
  };
}
