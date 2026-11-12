/*
  feat/desktop/manager/xfce

Enables the XFCE desktop environment and window manager.

Exposes:

- flake.homeModules."feat/desktop/manager/xfce":
  - Configures XFCE desktop settings and preferred applications.

- flake.nixosModules."feat/desktop/manager/xfce":
  - Enables XFCE desktop manager and registers built-in apps in `common/handlers`
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

  flake.homeModules.${moduleName} = {pkgs, ...}: {
    imports = [./_settings.nix];
    mod.meta = {
      imported = [moduleName];
      asserts = ["pairedNixosFeat"];
    };
    home.packages = with pkgs; [
      kando
    ];
  };

  flake.nixosModules.${moduleName} = {
    config,
    pkgs,
    utils,
    ...
  }: let
    hasPkg = pkg:
      utils.disablePackageByName pkg config.environment.xfce.excludePackages;
    hasParole = hasPkg pkgs.parole;
  in {
    mod = {
      meta.imported = [moduleName];
      "common/handlers".add = {
        terminal.xfce4-terminal = {
          enable = hasPkg pkgs.xfce4-terminal;
          priority = 200;
          label = "Xfce Terminal";
          desktop = "xfce4-terminal.desktop";
          cmd = ["xfce4-terminal"];
        };
        fileManager.thunar = {
          enable = config.programs.thunar.enable;
          priority = 200;
          label = "Thunar";
          desktop = "thunar.desktop";
          cmd = ["thunar"];
        };
        editor.mousepad = {
          enable = hasPkg pkgs.mousepad;
          priority = 200;
          label = "Mousepad";
          desktop = "org.xfce.mousepad.desktop";
          cmd = ["mousepad"];
        };
        imageViewer.ristretto = {
          enable = hasPkg pkgs.ristretto;
          priority = 200;
          label = "Ristretto";
          desktop = "org.xfce.ristretto.desktop";
          cmd = ["ristretto"];
        };
        audioPlayer.parole = {
          enable = hasParole;
          priority = 200;
          label = "Parole";
          desktop = "org.xfce.Parole.desktop";
          cmd = ["parole"];
        };
        videoPlayer.parole = {
          enable = hasParole;
          priority = 200;
          label = "Parole";
          desktop = "org.xfce.Parole.desktop";
          cmd = ["parole"];
        };
      };
    };
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
