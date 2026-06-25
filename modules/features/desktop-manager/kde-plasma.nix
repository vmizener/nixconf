/*
  feat/desktop-manager/kde

Enables the KDE Plasma 6 desktop environment.

Exposes:

- flake.nixosModules."feat/desktop-manager/kde":
  - Enables KDE Plasma 6 desktop manager
  - Configures X11/Wayland windowing system.
*/
{inputs, ...}: {
  flake.homeModules."feat/desktop-manager/kde-plasma" = {pkgs, ...}: {
    imports = [
      inputs.plasma-manager.homeModules.plasma-manager
    ];
    home.packages = with pkgs; [
      kando
    ];
    programs.plasma = {
      enable = true;
      overrideConfig = true;
      workspace = {
        cursor = {
          theme = "Bibata-Modern-Ice";
          size = 32;
        };
        iconTheme = "Papirus-Dark";
        # wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Patak/contents/images/1080x1920.png";
        wallpaper = ../../../assets/media/girl_leaving_apartment.jpg;
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

  flake.nixosModules."feat/desktop-manager/kde-plasma" = {...}: {
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
