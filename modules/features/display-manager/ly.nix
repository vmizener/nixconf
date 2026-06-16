/*
  feat/display-manager/ly

Enables the Ly TUI display manager.

Exposes:

- flake.nixosModules."feat/display-manager/ly":
*/
{
  flake.nixosModules."feat/display-manager/ly" = {
    services.displayManager.ly.enable = true;
  };
}
