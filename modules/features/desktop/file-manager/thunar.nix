/*
  feat/desktop/file-manager/thunar

Thunar XFCE file manager.

Exposes:

- flake.homeModules."feat/desktop/file-manager/thunar":
*/
{...}: let
  moduleName = "feat/desktop/file-manager/thunar";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    home.packages = with pkgs; [thunar];
    mod."common/handlers".add.fileManager.thunar = {
      priority = 150;
      label = "Thunar";
      desktop = "thunar.desktop";
      cmd = ["thunar"];
    };
  };
}
