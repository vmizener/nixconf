/*
  feat/browser/thunar

Thunar XFCE file manager.

Exposes:

- flake.homeModules."feat/file-manager/thunar":
*/
{
  flake.homeModules."feat/file-manager/thunar" = {
    config,
    lib,
    pkgs,
    ...
  }: {
    features.system.mime.categories.fileManagers = lib.mkIf config.features.system.mime.enable (lib.mkOrder 150 ["thunar.desktop"]);
    home.packages = with pkgs; [thunar];
  };
}
