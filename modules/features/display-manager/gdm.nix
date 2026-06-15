{ self, ... }: {
  flake.nixosModules = self.lib.mkSelectorChoice {
    featureName = "display-manager";
    selectionName = "gdm";
    target = "nixosModules";
    module = {
      services.displayManager.gdm.enable = true;
    };
  };
}
