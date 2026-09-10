/*
  feat/desktop-manager/awesome

Enables the awesome X11 tiling desktop environment.

Exposes:

- flake.nixosModules."feat/desktop-manager/awesome":
*/
{...}: let
  moduleName = "feat/desktop-manager/awesome";
in {
  flake.nixosModules.${moduleName} = {pkgs, ...}: {
    mod.imported = [moduleName];
    services.displayManager = {
      defaultSession = "none+awesome";
    };
    services.xserver = {
      enable = true;
      displayManager.startx.enable = true;
      windowManager.awesome = {
        enable = true;
        luaModules = with pkgs.luaPackages; [
          luarocks
          luadbi-mysql
        ];
      };
    };
  };
}
