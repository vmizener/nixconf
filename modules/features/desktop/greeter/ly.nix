/*
  feat/desktop/greeter/ly

Enables the Ly TUI display manager.

Exposes:

- flake.nixosModules."feat/desktop/greeter/ly":
*/
{...}: let
  moduleName = "feat/desktop/greeter/ly";
in {
  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
    services.displayManager.ly.enable = true;
  };
}
