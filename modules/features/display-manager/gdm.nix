/*
  feat/display-manager/gdm

Enables the GNOME Display Manager (GDM).

Exposes:

- flake.nixosModules."feat/display-manager/gdm":
*/
{...}: let
  moduleName = "feat/display-manager/gdm";
in {
  flake.nixosModules.${moduleName} = {...}: {
    flake.imported = [moduleName];
    services.displayManager.gdm.enable = true;
  };
}
