/*
  feat/media/reader/evince

Enables GNOME's evince document viewer.

Exposes:

- flake.homeModules."feat/media/reader/evince":
*/
{...}: let
  moduleName = "feat/media/reader/evince";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    home.packages = [pkgs.evince];

    mod."common/mime".add.pdfViewer."evince.desktop" = 150;
  };
}
