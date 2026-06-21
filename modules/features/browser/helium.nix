/*
  feat/browser/helium

Helium.

Exposes:

- flake.homeModules."feat/browser/helium":
*/
{inputs, ...}: {
  flake.homeModules."feat/browser/helium" = {pkgs, ...}: {
    home.packages = [
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
