{
  lib,
  self,
  ...
}: {
  # Automatically merge homeModules, similar to nixosModules
  options.flake.homeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = {};
    description = "Home-manager modules";
  };

  config = {
    # Modules to enable common modules and settings
    flake.homeModules."common" = {
      imports = [
        self.homeModules."common/options"
      ];
      home.stateVersion = "25.11";
    };
    flake.nixosModules."common" = {
      imports = [
        self.nixosModules."common/options"
      ];
      nix.settings.experimental-features = [
        "flakes"
        "nix-command"
        "pipe-operators"
      ];
    };

    # Declare supported systems
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    # Define standard formatter
    perSystem = {pkgs, ...}: {
      # formatter = pkgs.nixpkgs-fmt;
      formatter = pkgs.alejandra;
    };
  };
}
