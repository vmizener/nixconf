/*
  feat/nvim

Provides Neovim.

Exposes:

- flake.homeModules."feat/nvim":
  - Enables Neovim
*/
{
  flake.homeModules."feat/nvim" = {
    lib,
    pkgs,
    ...
  }: {
    programs.neovim = {
      enable = true;
      extraPackages = with pkgs; [
        black
        fd
        nixd
        nixfmt
        pyright
        ripgrep
      ];
      withPython3 = true;
      withRuby = false;
    };
    home.sessionVariables.EDITOR = lib.mkOverride 100 "nvim";
  };
}
