{ self, ... }: {
  flake.nixosModules = self.lib.mkSelectorChoice {
    featureName = "desktop-manager";
    selectionName = "gnome";
    target = "nixosModules";
    module = {
      services = {
        desktopManager.gnome.enable = true;
        xserver = {
          enable = true;
          xkb = {
            layout = "us";
            variant = "";
          };
        };
      };
    };
  };
}
