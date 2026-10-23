{
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

  # Automatically merge homeConfigurations, similar to nixosConfigurations
  options.flake.homeConfigurations = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Home-manager configurations";
  };

  config = let
    ################
    # Common options for both Home-Manager and NixOS modules
    commonOptions = {config, ...}: {
      options = {
        # Mutable options
        mod.imported = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          apply = lib.unique;
          description = "List of imported modules";
        };

        # Readonly options
        mod.has = lib.mkOption {
          default = name:
            if !(self.nixosModules ? ${name} || self.homeModules ? ${name})
            then throw "mod.has: unknown module '${name}'"
            else builtins.elem name config.mod.imported;
          description = "Check whether a module has been imported";
          readOnly = true;
        };
      };
    };
  in {
    ################
    # Home-Manager module options
    flake.homeModules."common/options" = {
      config,
      osConfig ? null,
      ...
    }: {
      imports = [commonOptions];
      options = {
        # Mutable options
        mod.asserts = lib.mkOption {
          type = lib.types.listOf (lib.types.enum [
            "nixosOnly" # Module is for nixos configs only
            "standaloneOnly" # Module is for standalone home-manager configs only
            "pairedNixosFeat" # Module must be paired with nixos feat import if on nixos
            "conflictsNixosFeat" # Module conflicts with nixos feature; must import only one
          ]);
          default = [];
          apply = lib.unique;
          description = "Common assertions enforced for each Home-Manager module setting them.";
        };

        mod.nixconf.path = lib.mkOption {
          type = lib.types.str;
          default =
            if osConfig != null
            then osConfig.mod.nixconf.path or "/etc/nixos"
            else "${config.xdg.configHome}/home-manager";
          description = "Absolute path to this Nix flake (outside Nix store).  Used for NH_FLAKE and out-of-store symlinks.";
        };

        # Readonly options
        mod.nixconf.link = lib.mkOption {
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
    # NixOS module options
    flake.nixosModules."common/options" = {...}: {
      imports = [commonOptions];
      options = {
        mod.nixconf.path = lib.mkOption {
          type = lib.types.str;
          default = "/etc/nixos";
          description = "Absolute path to this Nix flake (outside Nix store).  Used for NH_FLAKE.";
        };
      };
    };
  };
}
