/*
  feat/tools/evince

Enables GNOME's evince document viewer.

Exposes:

- flake.homeModules."feat/tools/evince":
*/
{
  flake.homeModules."feat/tools/evince" = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = [pkgs.evince];

    features.system.mime.categories.pdfViewers = lib.mkIf config.features.system.mime.enable (lib.mkOrder 150 ["evince.desktop"]);
  };
}
