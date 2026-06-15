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
