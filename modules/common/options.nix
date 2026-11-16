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
          # Disallow standalone HM (`osConfig != null`); NixOS hosts only.
          "nixosOnly"
          # Disallow NixOS HM (`osConfig == null`); standalone `homeConfigurations` only.
          "standaloneOnly"
          # Allowed standalone; on NixOS, requires paired `nixosModules.<name>` to also be imported.
          "pairedNixosFeat"
          # Allowed standalone; on NixOS, forbids importing `nixosModules.<name>` alongside this module.
          "conflictsNixosFeat"
        ]);
        default = [];
        apply = lib.unique;
        description = ''
          Host/boundary assertions enforced for each Home-Manager module setting them:

          - `"nixosOnly"`: Disallows standalone Home-Manager (`osConfig != null`); only usable on NixOS hosts.
          - `"standaloneOnly"`: Disallows NixOS Home-Manager (`osConfig == null`); only usable in standalone `homeConfigurations`.
          - `"pairedNixosFeat"`: Allowed in standalone Home-Manager; when imported on a NixOS host, requires the matching `flake.nixosModules.<name>` feature to also be imported.
          - `"conflictsNixosFeat"`: Allowed in standalone Home-Manager; when imported on a NixOS host, forbids importing the matching `flake.nixosModules.<name>` feature alongside it.
        '';
      };

      flakePath = lib.mkOption {
        type = lib.types.str;
        default =
          if osConfig != null
          then osConfig.mod.meta.flakePath or "/etc/nixos"
          else "${config.xdg.configHome}/home-manager";
        description = "Absolute path to the deployment flake (outside Nix store).  Used for NH_FLAKE.";
      };

      nixconfPath = lib.mkOption {
        type = lib.types.str;
        default =
          if osConfig != null && (osConfig.mod.meta.nixconfPath or null) != null
          then osConfig.mod.meta.nixconfPath
          else "${config.xdg.dataHome}/nixconf";
        defaultText = lib.literalExpression ''
          if osConfig != null && osConfig.mod.meta.nixconfPath != null
          then osConfig.mod.meta.nixconfPath
          else "''${config.xdg.dataHome}/nixconf"
        '';
        description = "Absolute path to the local nixconf repository checkout (outside Nix store).  Used for out-of-store symlinks via `mod.meta.link`.";
      };

      link = lib.mkOption {
        default = filepath: let
          relpath = lib.removePrefix "./" (lib.path.removePrefix ./../.. filepath);
        in
          config.lib.file.mkOutOfStoreSymlink "${config.mod.meta.nixconfPath}/${relpath}";
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
        description = "Absolute path to the deployment flake (outside Nix store).  Used for NH_FLAKE.";
      };

      nixconfPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional host-wide path to the local nixconf checkout (inherited by Home-Manager users when set).";
      };
    };
  };
}
