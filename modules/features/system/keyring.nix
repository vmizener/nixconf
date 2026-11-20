/*
  feat/system/keyring

Provides system keyring services via GNOME Keyring and registers it with
`common/keyring`.

Exposes:

- flake.nixosModules."feat/system/keyring":
  - Registers `gnome-keyring` as the active `common/keyring` provider and `Secret` portal
  - Enables GNOME Keyring service (including TTY login PAM integration) and unlocks
    registered `mod."common/keyring".pamServices`
  - Installs `libsecret` CLI utilities (`secret-tool`)
*/
{...}: let
  moduleName = "feat/system/keyring";
in {
  flake.nixosModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: {
    mod = {
      meta.imported = [moduleName];
      "common/keyring".providers.gnome-keyring.portal = "gnome-keyring";
    };
    services.gnome.gnome-keyring.enable = true;
    environment.systemPackages = [pkgs.libsecret];
    security.pam.services = lib.genAttrs config.mod."common/keyring".pamServices (_: {
      enableGnomeKeyring = true;
    });
  };
}
