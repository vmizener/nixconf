/*
  feat/desktop-manager/xfce

Enables the XFCE desktop environment and window manager.

Exposes:

- flake.nixosModules."feat/desktop-manager/xfce":
  - Enables XFCE desktop manager
  - Configures X11 server.
*/
{...}: let
  moduleName = "feat/desktop-manager/xfce";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    flake.imported = [moduleName];
    home.packages = with pkgs; [
      kando
    ];
    xfconf = {
      enable = true;
      settings = {
        # TODO: lookup xfconf-query
      };
    };
  };
  flake.nixosModules.${moduleName} = {...}: {
    flake.imported = [moduleName];
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
