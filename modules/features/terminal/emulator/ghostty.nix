/*
  feat/terminal/emulator/ghostty

Enables ghostty terminal emulator.

Exposes:

- flake.homeModules."feat/terminal/emulator/ghostty":
*/
{
  flake.homeModules."feat/terminal/emulator/ghostty" = {pkgs, ...}: {
    features.terminal.emulators = ["ghostty"];
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
        if pkgs.stdenv.isDarwin
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
    features.system.mime.add.terminal."ghostty.desktop" = 150;
  };
}
