/*
  feat/desktop/greeter/ly

Enables the Ly TUI display manager.

Exposes:

- flake.nixosModules."feat/desktop/greeter/ly":
  - Enables Ly display manager and registers `ly` for PAM keyring unlocking in `common/keyring`
*/
{...}: let
  moduleName = "feat/desktop/greeter/ly";
in {
  flake.nixosModules.${moduleName} = {...}: {
    mod = {
      meta.imported = [moduleName];
      "common/keyring".pamServices = ["ly"];
    };
    services.displayManager.ly.enable = true;
  };
}
