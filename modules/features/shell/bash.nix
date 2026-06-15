{ self, ... }: {
  flake.nixosModules = self.lib.mkSelectorChoice {
    featureName = "shell";
    selectionName = "bash";
    target = "nixosModules";
    module = {
    };
  };
}
