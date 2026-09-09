{
  inputs,
  lib,
  self,
  ...
}: {
  ################
  # Global options

  # Automatically merge homeModules, similar to nixosModules
  options.flake.homeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = {};
    description = "Home-manager modules";
  };

  config = {
    ################
    # Home-Manager common options
    flake.homeModules."common/options" = {
      config,
      osConfig ? null,
      ...
    }: {
      options.flake.imported = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of imported modules";
      };

      options.flakePath = lib.mkOption {
        type = lib.types.str;
        default =
          if osConfig != null
          then "/etc/nixos"
          else "${config.xdg.configHome}/home-manager";
        description = "Absolute path to this Nix flake (outside Nix store).  Used for out-of-store symlinks.";
      };

      options.mutableLink = lib.mkOption {
        default = filepath: let
          relpath = lib.removePrefix "./" (lib.path.removePrefix ./.. filepath);
        in
          config.lib.file.mkOutOfStoreSymlink "${config.flakePath}/${relpath}";
        description = "Make a mutable symlink path to the given config source";
        readOnly = true;
      };
    };

    ################
    # NixOS common options
    flake.nixosModules."common/options" = {...}: {
      options.flake.imported = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of imported modules";
      };
    };

    ################
    # Dummy configs to expose options to nixd
    flake.nixdOptions = {
      home = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
        modules = [
          {
            home.stateVersion = "25.11";
            home.username = "options";
            home.homeDirectory = "/home/options";
          }
          self.homeModules."common/options"

          # Expose upstream flakes
          inputs.plasma-manager.homeModules.plasma-manager
          inputs.dms.homeModules.dank-material-shell
          inputs.danksearch.homeModules.default
          inputs.niri.homeModules.niri
          inputs.soh-flake.homeManagerModules.default
          inputs.sops-nix.homeManagerModules.sops
          inputs.nix-index-database.homeModules.nix-index
        ];
      };
      nixos = inputs.nixpkgs.lib.nixosSystem {
        modules = [
          {
            system.stateVersion = "25.11";
            nixpkgs.hostPlatform = "x86_64-linux";
          }
          self.nixosModules."common/options"

          # Expose upstream flakes
          inputs.home-manager.nixosModules.home-manager
          inputs.niri.nixosModules.niri
        ];
      };
    };
  };
}
