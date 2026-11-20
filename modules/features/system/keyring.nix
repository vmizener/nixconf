/*
  feat/system/keyring

Provides system keyring services via GNOME Keyring.

Exposes:

- flake.nixosModules."feat/system/keyring":
  - Enables GNOME Keyring service
  - Configures PAM integration for TTY login
*/
{...}: let
  moduleName = "feat/system/keyring";
in {
  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
  };
}
