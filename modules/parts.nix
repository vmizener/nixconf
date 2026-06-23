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
      programs.home-manager.enable = true; # Home-Manager installs and manages itself
      systemd.user.startServices = "sd-switch"; # Reload system units on config change
      xdg = {
        enable = true; # Enable XDG directory management
        mime.enable = true; # Enable MIME-type support
      };
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
