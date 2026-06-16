/*
  feat/desktop-manager

Provides desktop environment selection mechanisms.

Exposes:

- flake.nixosModules."feat/desktop-manager":
  - Selector module for NixOS desktop environments (defaults to niri).

- flake.homeModules."feat/desktop-manager":
  - Selector module for Home Manager desktop environments (defaults to niri).
*/
{ self, ... }: {
  flake.homeModules = self.lib.mkSelectorFeature {
    featureName = "desktop-manager";
    defaultSelection = "niri";
    target = "homeModules";
    isMulti = true;
  };
  flake.nixosModules = self.lib.mkSelectorFeature {
    featureName = "desktop-manager";
    defaultSelection = "niri";
    target = "nixosModules";
    isMulti = true;
  };
}
