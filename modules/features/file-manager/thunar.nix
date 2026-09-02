/*
  feat/browser/thunar

Thunar XFCE file manager.

Exposes:

- flake.homeModules."feat/file-manager/thunar":
*/
{
  flake.homeModules."feat/file-manager/thunar" = {pkgs, ...}: {
    home.packages = with pkgs; [thunar];
    features.system.mime.add.fileManager."thunar.desktop" = 150;
  };
}
