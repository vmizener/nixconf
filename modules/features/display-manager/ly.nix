{ self, ... }: {
  flake.nixosModules = self.lib.mkSelectorChoice {
    featureName = "display-manager";
    selectionName = "ly";
    target = "nixosModules";
    module = {
      services.displayManager.ly.enable = true;
    };
  };
}
