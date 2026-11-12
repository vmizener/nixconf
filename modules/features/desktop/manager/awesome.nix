/*
  feat/desktop/manager/awesome

Enables the awesome X11 tiling desktop environment.

Exposes:

- flake.nixosModules."feat/desktop/manager/awesome":
  - Enables Awesome window manager and registers X11 `xterm` fallback in `common/handlers`.
*/
{...}: let
  moduleName = "feat/desktop/manager/awesome";
in {
  flake.nixosModules.${moduleName} = {
    config,
    pkgs,
    utils,
    ...
  }: {
    mod = {
      meta.imported = [moduleName];
      "common/handlers".add.terminal.xterm = {
        enable = utils.disablePackageByName pkgs.xterm config.services.xserver.excludePackages;
        priority = 300;
        label = "XTerm";
        desktop = "xterm.desktop";
        cmd = ["xterm"];
      };
    };
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
