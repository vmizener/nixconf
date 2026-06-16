/*
  feat/secrets

Provides secret management and keyring services.

Exposes:

- flake.nixosModules."feat/secrets":
  - Enables GNOME Keyring service
  - Configures PAM integration for login and greetd.
*/
{ self, ... }: {
  flake.nixosModules."feat/secrets" = {
    config = {
      services.gnome.gnome-keyring.enable = true;
      security.pam.services = {
        login.enableGnomeKeyring = true;
        greetd.enableGnomeKeyring = true;
      };
    };
  };
}
