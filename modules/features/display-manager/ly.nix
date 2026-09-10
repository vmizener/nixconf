/*
  feat/display-manager/ly

Enables the Ly TUI display manager.

Exposes:

- flake.nixosModules."feat/display-manager/ly":
*/
{...}: let
  moduleName = "feat/display-manager/ly";
in {
  flake.nixosModules.${moduleName} = {...}: {
    mod.imported = [moduleName];
    services.displayManager.ly.enable = true;
  };
}
