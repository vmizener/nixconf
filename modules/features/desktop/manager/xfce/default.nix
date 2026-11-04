/*
  feat/desktop/manager/xfce

Enables the XFCE desktop environment and window manager.

Exposes:

- flake.homeModules."feat/desktop/manager/xfce":
  - Configures XFCE desktop settings and preferred applications.

- flake.nixosModules."feat/desktop/manager/xfce":
  - Enables XFCE desktop manager
  - Configures X11 server.
*/
{...}: let
  moduleName = "feat/desktop/manager/xfce";
in {
  flake.homeModules.${moduleName} = {
    config,
    lib,
    osConfig ? null,
    pkgs,
    ...
  }:
    lib.mkMerge [
      {
        mod.meta = {
          imported = [moduleName];
          asserts = ["pairedNixosFeat"];
        };
        home.packages = with pkgs; [
          kando
        ];
      }
      (import ./_settings.nix {
        inherit lib osConfig;
        hmConfig = config;
      })
    ];

  flake.nixosModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    programs.gdk-pixbuf.modulePackages = [pkgs.webp-pixbuf-loader];
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
