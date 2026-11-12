/*
  feat/desktop/manager/kde-plasma

Enables the KDE Plasma 6 desktop environment.

Exposes:

- flake.homeModules."feat/desktop/manager/kde-plasma":
  - Configures KDE Plasma 6 via plasma-manager.
- flake.nixosModules."feat/desktop/manager/kde-plasma":
  - Enables KDE Plasma 6 desktop manager and registers built-in apps in `common/handlers`
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
    inherit (config.mod."common/handlers".get) terminal;
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
      hotkeys.commands = lib.mkIf (terminal != null) {
        "launch-terminal" = {
          name = "Launch ${terminal.label}";
          key = "Meta+Alt+K";
          command =
            if terminal.cmd != null
            then lib.escapeShellArgs terminal.cmd
            else "xdg-terminal-exec";
        };
      };
      fonts = {
        general = {
          family = "JetBrains Mono";
          pointSize = 12;
        };
      };
    };
  };

  flake.nixosModules.${moduleName} = {
    config,
    pkgs,
    utils,
    ...
  }: let
    hasPkg = pkg:
      utils.disablePackageByName pkg config.environment.plasma6.excludePackages;
  in {
    mod = {
      meta.imported = [moduleName];
      "common/handlers".add = {
        terminal.konsole = {
          enable = hasPkg pkgs.kdePackages.konsole;
          priority = 200;
          label = "Konsole";
          desktop = "org.kde.konsole.desktop";
          cmd = ["konsole"];
        };
        fileManager.dolphin = {
          enable = hasPkg pkgs.kdePackages.dolphin;
          priority = 200;
          label = "Dolphin";
          desktop = "org.kde.dolphin.desktop";
          cmd = ["dolphin"];
        };
        editor.kate = {
          enable = hasPkg pkgs.kdePackages.kate;
          priority = 200;
          label = "Kate";
          desktop = "org.kde.kate.desktop";
          cmd = ["kate"];
        };
        imageViewer.gwenview = {
          enable = hasPkg pkgs.kdePackages.gwenview;
          priority = 200;
          label = "Gwenview";
          desktop = "org.kde.gwenview.desktop";
          cmd = ["gwenview"];
        };
        pdfViewer.okular = {
          enable = hasPkg pkgs.kdePackages.okular;
          priority = 200;
          label = "Okular";
          desktop = "okularApplication_pdf.desktop";
          cmd = ["okular"];
        };
        audioPlayer.elisa = {
          enable = hasPkg pkgs.kdePackages.elisa;
          priority = 200;
          label = "Elisa";
          desktop = "org.kde.elisa.desktop";
          cmd = ["elisa"];
        };
      };
    };
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
