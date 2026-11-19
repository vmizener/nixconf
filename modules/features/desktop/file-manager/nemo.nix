/*
  feat/desktop/file-manager/nemo

Nemo Cinnamon file manager.

Exposes:

- flake.homeModules."feat/desktop/file-manager/nemo":
  - Installs Nemo with default extensions on standalone Home-Manager, wires the
    `common/handlers` terminal into Nemo's "Open in Terminal" action, and registers
    Nemo in `common/handlers`.
- flake.nixosModules."feat/desktop/file-manager/nemo":
  - Installs Nemo with extensions and enables D-Bus `FileManager1`, dconf, GVfs,
    udisks2, and Tumbler on NixOS.
*/
{...}: let
  moduleName = "feat/desktop/file-manager/nemo";
in {
  flake.homeModules.${moduleName} = {
    config,
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: let
    inherit (config.mod."common/handlers".get) terminal;
  in {
    mod = {
      meta = {
        imported = [moduleName];
        asserts = ["pairedNixosFeat"];
      };
      "common/handlers".add.fileManager.nemo = {
        priority = 150;
        label = "Nemo";
        desktop = "nemo.desktop";
        cmd = ["nemo"];
      };
    };
    home.packages = lib.mkIf (osConfig == null) [pkgs.nemo-with-extensions];
    dconf.settings = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin && terminal != null) {
      "org/cinnamon/desktop/default-applications/terminal" = {
        exec = "xdg-terminal-exec";
        exec-arg = "--";
      };
    };
  };

  flake.nixosModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    environment.systemPackages = [pkgs.nemo-with-extensions];
    programs.dconf.enable = true;
    services = {
      dbus.packages = [pkgs.nemo-with-extensions];
      gvfs.enable = true;
      tumbler.enable = true;
      udisks2.enable = true;
    };
  };
}
