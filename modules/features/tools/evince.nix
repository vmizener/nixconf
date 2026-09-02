/*
  feat/tools/evince

Enables GNOME's evince document viewer.

Exposes:

- flake.homeModules."feat/tools/evince":
*/
{
  flake.homeModules."feat/tools/evince" = {pkgs, ...}: {
    home.packages = [pkgs.evince];

    features.system.mime.add.pdfViewer."evince.desktop" = 150;
  };
}
