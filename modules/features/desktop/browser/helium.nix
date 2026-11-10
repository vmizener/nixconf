/*
  feat/desktop/browser/helium

Helium.

Exposes:

- flake.homeModules."feat/desktop/browser/helium":
*/
{inputs, ...}: let
  moduleName = "feat/desktop/browser/helium";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    home.packages = [
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
    mod."common/handlers".add.browser.helium = {
      priority = 100;
      label = "Helium";
      desktop = "helium.desktop";
    };
  };
}
