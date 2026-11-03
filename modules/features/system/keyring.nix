/*
  feat/system/keyring

Provides system keyring services via GNOME Keyring.

Exposes:

- flake.nixosModules."feat/system/keyring":
  - Enables GNOME Keyring service
  - Configures PAM integration for login and greetd.
*/
{...}: let
  moduleName = "feat/system/keyring";
in {
  flake.nixosModules.${moduleName} = {...}: {
    config = {
      mod.imported = [moduleName];
      services.gnome.gnome-keyring.enable = true;
      security.pam.services = {
        login.enableGnomeKeyring = true;
        greetd.enableGnomeKeyring = true;
      };
    };
  };
}
