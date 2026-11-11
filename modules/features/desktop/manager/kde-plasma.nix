/*
  feat/desktop/manager/kde-plasma

Enables the KDE Plasma 6 desktop environment.

Exposes:

- flake.homeModules."feat/desktop/manager/kde-plasma":
  - Configures KDE Plasma 6 via plasma-manager.
- flake.nixosModules."feat/desktop/manager/kde-plasma":
  - Enables KDE Plasma 6 desktop manager
  - Configures X11/Wayland windowing system.
*/
{inputs, ...}: let
  moduleName = "feat/desktop/manager/kde-plasma";
in {
  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    hasTheme = config.mod.meta.has "feat/system/theme";
    themeCfg = config.mod."feat/system/theme";
  in {
    mod.meta = {
      imported = [moduleName];
      asserts = ["pairedNixosFeat"];
    };
    imports = [
      inputs.plasma-manager.homeModules.plasma-manager
    ];
    home.packages = with pkgs; [
      kando
    ];
    programs.plasma = {
      enable = true;
      overrideConfig = true;
      # Defer GTK config ownership to Home-Manager when `feat/system/theme` is active
      configFile = lib.mkIf hasTheme {
        kded5rc."Module-gtkconfig".autoload = false;
        kded6rc."Module-gtkconfig".autoload = false;
      };
      workspace = {
        cursor = {
          theme =
            if hasTheme
            then themeCfg.cursorTheme
            else "breeze_cursors";
          size =
            if hasTheme
            then themeCfg.cursorSize
            else 32;
        };
        iconTheme =
          if hasTheme
          then themeCfg.iconTheme
          else "breeze-dark";
        # wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Patak/contents/images/1080x1920.png";
        wallpaper = ../../../../assets/wallpapers/girl_leaving_apartment.png;
        wallpaperFillMode = "stretch";
      };
      hotkeys.commands."launch-konsole" = {
        name = "Launch Konsole";
        key = "Meta+Alt+K";
        command = "konsole";
      };
      fonts = {
        general = {
          family = "JetBrains Mono";
          pointSize = 12;
        };
      };
    };
  };

  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
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
