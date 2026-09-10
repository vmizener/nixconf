/*
  feat/tools/evince

Enables GNOME's evince document viewer.

Exposes:

- flake.homeModules."feat/tools/evince":
*/
{...}: let
  moduleName = "feat/tools/evince";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.imported = [moduleName];
    home.packages = [pkgs.evince];

    mod."feat/system/mime".add.pdfViewer."evince.desktop" = 150;
  };
}
