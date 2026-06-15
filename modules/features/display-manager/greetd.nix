{ self, ... }: {
  flake.nixosModules = self.lib.mkSelectorChoice {
    featureName = "display-manager";
    selectionName = "greetd";
    target = "nixosModules";
    module = { pkgs, ... }: {
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time";
            user = "greeter";
          };
        };
      };
    };
  };
}
