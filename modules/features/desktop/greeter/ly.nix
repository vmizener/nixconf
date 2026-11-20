/*
  feat/desktop/greeter/ly

Enables the Ly TUI display manager.

Exposes:

- flake.nixosModules."feat/desktop/greeter/ly":
  - Enables Ly display manager and unlocks GNOME Keyring via PAM when `feat/system/keyring` is active
*/
{...}: let
  moduleName = "feat/desktop/greeter/ly";
in {
  flake.nixosModules.${moduleName} = {
    config,
    lib,
    ...
  }: {
    mod.meta.imported = [moduleName];
    services.displayManager.ly.enable = true;
    security.pam.services.ly.enableGnomeKeyring = lib.mkIf (config.mod.meta.has "feat/system/keyring") true;
  };
}
