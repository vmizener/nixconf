/*
  feat/desktop-manager/kde

Enables the KDE Plasma 6 desktop environment.

Exposes:

- flake.nixosModules."feat/desktop-manager/kde":
  - Enables KDE Plasma 6 desktop manager
  - Configures X11/Wayland windowing system.
*/
{
  flake.nixosModules."feat/desktop-manager/kde-plasma" = {
    services = {
      desktopManager.plasma6.enable = true;
      xserver = {
        enable = true;
        xkb = {
          layout = "us";
          variant = "";
        };
      };
    };
  };
}
