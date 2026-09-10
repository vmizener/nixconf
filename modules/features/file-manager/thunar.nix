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
    mod.imported = [moduleName];
    home.packages = with pkgs; [thunar];
    mod."feat/system/mime".add.fileManager."thunar.desktop" = 150;
  };
}
