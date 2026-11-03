{
  lib,
  self,
  ...
}: let
  moduleName = "common/options";

  # Shared framework options for both Home-Manager and NixOS modules
  commonOptions = {config, ...}: {
    options.mod.meta = {
      imported = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        apply = lib.unique;
        description = "List of imported modules";
      };

      has = lib.mkOption {
        default = name:
          if !(self.nixosModules ? ${name} || self.homeModules ? ${name})
          then throw "mod.meta.has: unknown module '${name}'"
          else builtins.elem name config.mod.meta.imported;
        description = "Check whether a module has been imported";
        readOnly = true;
      };
    };

    config.mod.meta.imported = [moduleName];
  };
in {
  flake.homeModules.${moduleName} = {
    config,
    osConfig ? null,
    ...
  }: {
    imports = [commonOptions];
    options.mod.meta = {
      asserts = lib.mkOption {
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

      flakePath = lib.mkOption {
        type = lib.types.str;
        default =
          if osConfig != null
          then osConfig.mod.meta.flakePath or "/etc/nixos"
          else "${config.xdg.configHome}/home-manager";
        description = "Absolute path to this Nix flake (outside Nix store).  Used for NH_FLAKE and out-of-store symlinks.";
      };

      link = lib.mkOption {
        default = filepath: let
          relpath = lib.removePrefix "./" (lib.path.removePrefix ./../.. filepath);
        in
          config.lib.file.mkOutOfStoreSymlink "${config.mod.meta.flakePath}/${relpath}";
        description = "Make a mutable symlink path to the given config source";
        readOnly = true;
      };
    };
  };

  flake.nixosModules.${moduleName} = {...}: {
    imports = [commonOptions];
    options.mod.meta = {
      flakePath = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nixos";
        description = "Absolute path to this Nix flake (outside Nix store).  Used for NH_FLAKE.";
      };
    };
  };
}
