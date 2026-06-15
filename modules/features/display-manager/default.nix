{ self, ... }: {
  flake.nixosModules = self.lib.mkSelectorFeature {
    featureName = "display-manager";
    defaultSelection = "gdm";
    target = "nixosModules";
  };
}
