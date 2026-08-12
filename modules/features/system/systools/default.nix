/*
  feat/system/systools

Provides common utilities used for system administration and associated functionality.

Exposes:

- flake.nixosModules."feat/system/systools":
  - Installs user CLI tools
  - Enables udisks2.

- flake.homeModules."feat/system/systools":
  - Installs user CLI tools (deduplicated against NixOS systemPackages)
  - Configures udiskie automounting.
*/
{inputs, ...}: let
  systoolsPackages = import ./_packages.nix;
in {
  flake.homeModules."feat/system/systools" = {pkgs, ...}: {
    imports = [
      inputs.nix-index-database.homeModules.nix-index
    ];
    home.packages =
      (systoolsPackages pkgs)
      ++ (with pkgs; [
        comma
      ]);
    programs.nix-index.enable = true;
    services = {
      udiskie = {
        enable = true;
        automount = true;
      };
    };
    systemd.user.startServices = "sd-switch";
  };

  flake.nixosModules."feat/system/systools" = {pkgs, ...}: {
    environment.systemPackages = systoolsPackages pkgs;
    services = {
      udisks2.enable = true;
    };
  };
}
