/*
  feat/desktop-manager/gnome

Enables the GNOME desktop environment and X11 windowing system.

Exposes:

- flake.nixosModules."feat/desktop-manager/gnome":
  - Enables GNOME desktop manager
  - Configures X11 windowing system.
*/
{...}: let
  moduleName = "feat/desktop-manager/gnome";
in {
  flake.nixosModules.${moduleName} = {...}: {
    flake.imported = [moduleName];
    services = {
      desktopManager.gnome.enable = true;
      xserver = {
        enable = true;
        xkb = {
          layout = "us";
          variant = "";
        };
      };
    };
  };
}
