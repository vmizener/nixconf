/*
  feat/desktop/greeter/gdm

Enables the GNOME Display Manager (GDM).

Exposes:

- flake.nixosModules."feat/desktop/greeter/gdm":
*/
{...}: let
  moduleName = "feat/desktop/greeter/gdm";
in {
  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
    services.displayManager.gdm.enable = true;
  };
}
