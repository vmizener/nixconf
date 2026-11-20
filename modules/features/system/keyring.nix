/*
  feat/system/keyring

Provides system keyring services via GNOME Keyring.

Exposes:

- flake.nixosModules."feat/system/keyring":
  - Enables GNOME Keyring service (including TTY login PAM integration)
  - Installs `libsecret` CLI utilities (`secret-tool`)
  - Routes the XDG `Secret` desktop portal interface to `gnome-keyring` by default
*/
{...}: let
  moduleName = "feat/system/keyring";
in {
  flake.nixosModules.${moduleName} = {
    lib,
    pkgs,
    ...
  }: {
    mod.meta.imported = [moduleName];
    services.gnome.gnome-keyring.enable = true;
    environment.systemPackages = [pkgs.libsecret];
    xdg.portal.config.common."org.freedesktop.impl.portal.Secret" = lib.mkDefault "gnome-keyring";
  };
}
