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
      options.mod.imported = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of imported modules";
      };

      options.mod.nixconf = {
        path = lib.mkOption {
          type = lib.types.str;
          default =
            if osConfig != null
            then "/etc/nixos"
            else "${config.xdg.configHome}/home-manager";
          description = "Absolute path to this Nix flake (outside Nix store).  Used for out-of-store symlinks.";
        };

        link = lib.mkOption {
          default = filepath: let
            relpath = lib.removePrefix "./" (lib.path.removePrefix ./.. filepath);
          in
            config.lib.file.mkOutOfStoreSymlink "${config.mod.nixconf.path}/${relpath}";
          description = "Make a mutable symlink path to the given config source";
          readOnly = true;
        };
      };
    };

    ################
    # NixOS common options
    flake.nixosModules."common/options" = {...}: {
      options.mod.imported = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of imported modules";
      };
    };

    ################
    # Dummy configs to expose options to nixd
    flake.nixdOptions = let
      # Dynamically pick up all modules, ignoring those from these inputs
      ignoreInputs = [
        "nixpkgs"
        "wrapper-modules"
      ];
      pickModule = name: modSet:
        if modSet ? default # check for <module>.default
        then [modSet.default]
        else if modSet ? ${name} # check for <module>.<inputname>
        then [modSet.${name}]
        else [];
      collectModules = getModSet:
        lib.concatLists (
          lib.mapAttrsToList (
            name: inp:
              if builtins.elem name ignoreInputs
              then []
              else pickModule name (getModSet inp)
          )
          inputs
        );
      hmInputModules = collectModules (
        inp:
          inp.homeModules or inp.homeManagerModules or {}
      );
      nixosInputModules = collectModules (
        inp:
          inp.nixosModules or {}
      );
    in {
      home = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
        modules =
          [
            {
              home.stateVersion = "25.11";
              home.username = "options";
              home.homeDirectory = "/home/options";
            }
            self.homeModules."common/options"
          ]
          ++ hmInputModules;
      };
      nixos = inputs.nixpkgs.lib.nixosSystem {
        modules =
          [
            {
              system.stateVersion = "25.11";
              nixpkgs.hostPlatform = "x86_64-linux";
            }
            self.nixosModules."common/options"
          ]
          ++ nixosInputModules;
      };
    };
  };
}
