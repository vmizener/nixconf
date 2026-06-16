/*
  feat/display-manager/gdm

Enables the GNOME Display Manager (GDM).

Exposes:

- flake.nixosModules."feat/display-manager/gdm":
*/
{
  flake.nixosModules."feat/display-manager/gdm" = {
    services.displayManager.gdm.enable = true;
  };
}
