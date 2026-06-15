{ self, ... }: {
  flake.homeModules = self.lib.mkSelectorFeature {
    featureName = "shell";
    defaultSelection = "zsh";
    target = "homeModules";
    isMulti = true;
  };
  flake.nixosModules = self.lib.mkSelectorFeature {
    featureName = "shell";
    defaultSelection = "zsh";
    target = "nixosModules";
    isMulti = true;
  };
}
