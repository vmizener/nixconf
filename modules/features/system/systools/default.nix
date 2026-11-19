/*
  feat/system/systools

Provides common utilities used for system administration and associated functionality.

Set mod."feat/system/systools".categories to specify requested toolsets.
Available toolsets: ["core", "sysadmin", "media", "desktop"] (default is all)

Exposes:

- flake.nixosModules."common/options" (options.mod."feat/system/systools")
- flake.homeModules."common/options" (options.mod."feat/system/systools")
- flake.nixosModules."feat/system/systools":
  - Installs user CLI tools
  - Enables udisks2.
- flake.homeModules."feat/system/systools":
  - Installs user CLI tools (deduplicated against NixOS `feat/system/systools`)
  - Configures udiskie automounting.
*/
{
  inputs,
  lib,
  ...
}: let
  moduleName = "feat/system/systools";

  systoolsPackages = import ./_packages.nix;
  allCategories = builtins.attrNames (systoolsPackages null);

  selectPackages = pkgs: categories:
    lib.concatMap (cat: (systoolsPackages pkgs).${cat}) (lib.unique categories);

  mkSystoolsOptions = osSystools: {
    categories = lib.mkOption {
      type = lib.types.listOf (lib.types.enum allCategories);
      default =
        if osSystools != null
        then osSystools.categories
        else allCategories;
      defaultText = lib.literalExpression (builtins.toJSON allCategories);
      description = "Systools package categories to install.";
    };
  };
in {
  flake.nixosModules."common/options" = {...}: {
    options.mod.${moduleName} = mkSystoolsOptions null;
  };

  flake.homeModules."common/options" = {osConfig ? null, ...}: let
    osSystools =
      if osConfig != null && osConfig.mod.meta.has moduleName
      then osConfig.mod.${moduleName}
      else null;
  in {
    options.mod.${moduleName} = mkSystoolsOptions osSystools;
  };

  flake.homeModules.${moduleName} = {
    config,
    osConfig ? null,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    hasCategory = cat: builtins.elem cat cfg.categories;
    osCategories =
      if osConfig != null && osConfig.mod.meta.has moduleName
      then osConfig.mod.${moduleName}.categories
      else [];
    hmCategories = builtins.filter (cat: !(builtins.elem cat osCategories)) cfg.categories;
  in {
    imports = [
      inputs.nix-index-database.homeModules.nix-index
    ];
    config = lib.mkMerge [
      # Base Config
      {
        mod.meta.imported = [moduleName];
        home.packages = selectPackages pkgs hmCategories;
        systemd.user.startServices = "sd-switch";
      }
      # Core-Only Config
      (lib.mkIf (hasCategory "core") {
        home.packages = [pkgs.comma];
        programs.nix-index.enable = true;
        xdg.configFile."ov/config.yaml".source = config.mod.meta.link ./configs/ov.yaml;
      })
      # Sysadmin-Only Config
      (lib.mkIf (hasCategory "sysadmin") {
        xdg.configFile."btop/btop.conf".source = config.mod.meta.link ./configs/btop.conf;
      })
      # Desktop-Only Config
      (lib.mkIf (hasCategory "desktop") {
        mod.meta.asserts = ["nixosOnly" "pairedNixosFeat"];
        services.udiskie = {
          enable = true;
          automount = true;
        };
      })
    ];
  };

  flake.nixosModules.${moduleName} = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.meta.imported = [moduleName];
    environment.systemPackages = selectPackages pkgs cfg.categories;
    services = {
      udisks2.enable = true;
    };
  };
}
