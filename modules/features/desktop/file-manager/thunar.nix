/*
  feat/desktop/file-manager/thunar

Thunar XFCE file manager.

Exposes:

- flake.homeModules."feat/desktop/file-manager/thunar":
  - Installs Thunar on standalone Home-Manager and registers it in `common/handlers`.
- flake.nixosModules."feat/desktop/file-manager/thunar":
  - Enables Thunar, xfconf, GVfs, and Tumbler on NixOS.
*/
{...}: let
  moduleName = "feat/desktop/file-manager/thunar";
in {
  flake.homeModules.${moduleName} = {
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: {
    mod = {
      meta = {
        imported = [moduleName];
        asserts = ["pairedNixosFeat"];
      };
      "common/handlers".add.fileManager.thunar = {
        priority = 150;
        label = "Thunar";
        desktop = "thunar.desktop";
        cmd = ["thunar"];
      };
    };
    home.packages = lib.mkIf (osConfig == null) [pkgs.thunar];
  };

  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
    programs = {
      thunar.enable = true;
      xfconf.enable = true;
    };
    services = {
      gvfs.enable = true;
      tumbler.enable = true;
    };
  };
}
