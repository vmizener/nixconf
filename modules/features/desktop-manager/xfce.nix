{ self, ... }: {
  flake.nixosModules = self.lib.mkSelectorChoice {
    featureName = "desktop-manager";
    selectionName = "xfce";
    target = "nixosModules";
    module = {
      services.xserver = {
        enable = true;
        desktopManager = {
          xfce.enable = true;
          xterm.enable = false;
        };
      };
    };
  };
}
