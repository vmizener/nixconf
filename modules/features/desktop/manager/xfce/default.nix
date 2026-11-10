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
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      wallpaper = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = ../../../../../assets/wallpapers/girl_adjusting_glasses.png;
        description = "Path to image used for the XFCE desktop wallpaper.";
      };
    };
  };

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
        inherit lib osConfig pkgs;
        hmConfig = config;
      })
    ];

  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
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
