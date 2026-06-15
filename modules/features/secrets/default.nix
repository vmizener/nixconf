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
