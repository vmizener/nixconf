/*
  feat/browser/helium

Helium.

Exposes:

- flake.homeModules."feat/browser/helium":
*/
{inputs, ...}: {
  flake.homeModules."feat/browser/helium" = {config, lib, pkgs, ...}: {
    home.packages = [
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
    features.system.mime.categories.browsers = lib.mkIf config.features.system.mime.enable (lib.mkOrder 100 ["helium.desktop"]);
  };
}
