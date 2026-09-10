/*
  feat/terminal/emulator/ghostty

Enables ghostty terminal emulator.

Exposes:

- flake.homeModules."feat/terminal/emulator/ghostty":
*/
{...}: let
  moduleName = "feat/terminal/emulator/ghostty";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.imported = [moduleName];
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      nerd-fonts.inconsolata
    ];
    programs.ghostty = {
      enable = true;
      package =
        if pkgs.stdenv.hostPlatform.isDarwin
        then pkgs.ghostty-bin
        else pkgs.ghostty;
      enableZshIntegration = true;
      settings = {
        background-opacity = "0.7";
        background-blur = "20";
        font-family = "Hack Nerd Font Mono";
        # theme = "Abernathy";
        theme = "Nocturnal Winter";
      };
    };
    mod."feat/system/mime".add.terminal."ghostty.desktop" = 150;
  };
}
