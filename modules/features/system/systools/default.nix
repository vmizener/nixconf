/*
  feat/system/systools

Provides common utilities used for system administration and associated functionality.

Set mod.${moduleName}.categories to specify requested toolsets.
Available toolsets: ["core", "sysadmin", "desktop"] (default is all)

Exposes:

- flake.nixosModules."feat/system/systools":
  - Installs user CLI tools
  - Enables udisks2.

- flake.homeModules."feat/system/systools":
  - Installs user CLI tools (deduplicated against NixOS systemPackages)
  - Configures udiskie automounting.
*/
{inputs, ...}: let
  moduleName = "feat/system/systools";

  systoolsPackages = import ./_packages.nix;

  allCategories = builtins.attrNames (systoolsPackages null);
  systoolsOptions = {lib, ...}: {
    options.mod.${moduleName} = {
      categories = lib.mkOption {
        type = lib.types.listOf (lib.types.enum allCategories);
        default = allCategories;
        description = "Systools package categories to install.";
      };
    };
  };

  selectPackages = lib: pkgs: categories:
    lib.concatMap (cat: (systoolsPackages pkgs).${cat}) (lib.unique categories);
in {
  flake.nixosModules."common/options" = systoolsOptions;
  flake.homeModules."common/options" = systoolsOptions;

  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    hasCategory = cat: builtins.elem cat cfg.categories;
  in {
    imports = [
      inputs.nix-index-database.homeModules.nix-index
    ];
    config = lib.mkMerge [
      # Base Config
      {
        mod.imported = [moduleName];
        home.packages = selectPackages lib pkgs cfg.categories;
        systemd.user.startServices = "sd-switch";
      }
      # Core-Only Config
      (lib.mkIf (hasCategory "core") {
        home.packages = with pkgs; [
          comma
        ];
        programs.nix-index.enable = true;
      })
      # Desktop-Only Config
      (lib.mkIf (hasCategory "desktop") {
        services.udiskie = {
          enable = true;
          automount = true;
        };
      })
    ];
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.imported = [moduleName];
    environment.systemPackages = selectPackages lib pkgs cfg.categories;
    services = {
      udisks2.enable = true;
    };
  };
}
