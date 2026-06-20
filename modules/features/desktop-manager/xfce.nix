/*
  feat/desktop-manager/xfce

Enables the XFCE desktop environment and window manager.

Exposes:

- flake.nixosModules."feat/desktop-manager/xfce":
  - Enables XFCE desktop manager
  - Configures X11 server.
*/
{
  flake.nixosModules."feat/desktop-manager/xfce" = {
    services.xserver = {
      enable = true;
      desktopManager = {
        xfce.enable = true;
        xterm.enable = false;
      };
      displayManager.startx.enable = true;
    };
  };
}
