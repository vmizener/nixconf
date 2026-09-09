/*
  feat/browser/thunar

Thunar XFCE file manager.

Exposes:

- flake.homeModules."feat/file-manager/thunar":
*/
{...}: let
  moduleName = "feat/file-manager/thunar";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    flake.imported = [moduleName];
    home.packages = with pkgs; [thunar];
    features.system.mime.add.fileManager."thunar.desktop" = 150;
  };
}
