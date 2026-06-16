/*
  feat/display-manager

Provides login and display manager selection mechanisms.

Exposes:

- flake.nixosModules."feat/display-manager":
  - Selector module for NixOS display managers (defaults to gdm).
*/
{ self, ... }: {
  flake.nixosModules = self.lib.mkSelectorFeature {
    featureName = "display-manager";
    defaultSelection = "gdm";
    target = "nixosModules";
  };
}
