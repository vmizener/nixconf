/*
  feat/browser/helium

Helium.

Exposes:

- flake.homeModules."feat/browser/helium":
*/
{inputs, ...}: let
  moduleName = "feat/browser/helium";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    flake.imported = [moduleName];
    home.packages = [
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
    features.system.mime.add.browser."helium.desktop" = 100;
  };
}
