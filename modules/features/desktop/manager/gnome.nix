/*
  feat/desktop/manager/gnome

Enables the GNOME desktop environment and X11 windowing system.

Exposes:

- flake.nixosModules."feat/desktop/manager/gnome":
  - Enables GNOME desktop manager and registers built-in core apps in `common/handlers`
  - Configures X11 windowing system.
*/
{...}: let
  moduleName = "feat/desktop/manager/gnome";
in {
  flake.nixosModules.${moduleName} = {
    config,
    pkgs,
    utils,
    ...
  }: let
    coreApps = config.services.gnome.core-apps.enable;
    hasPkg = pkg:
      coreApps && utils.disablePackageByName pkg config.environment.gnome.excludePackages;
  in {
    mod = {
      meta.imported = [moduleName];
      "common/handlers".add = {
        terminal.gnome-console = {
          enable = hasPkg pkgs.gnome-console;
          priority = 200;
          label = "GNOME Console";
          desktop = "org.gnome.Console.desktop";
          cmd = ["kgx"];
        };
        fileManager.nautilus = {
          enable = hasPkg pkgs.nautilus;
          priority = 200;
          label = "Files";
          desktop = "org.gnome.Nautilus.desktop";
          cmd = ["nautilus"];
        };
        browser.epiphany = {
          enable = hasPkg pkgs.epiphany;
          priority = 200;
          label = "GNOME Web";
          desktop = "org.gnome.Epiphany.desktop";
          cmd = ["epiphany"];
        };
        editor.gnome-text-editor = {
          enable = hasPkg pkgs.gnome-text-editor;
          priority = 200;
          label = "GNOME Text Editor";
          desktop = "org.gnome.TextEditor.desktop";
          cmd = ["gnome-text-editor"];
        };
        imageViewer.loupe = {
          enable = hasPkg pkgs.loupe;
          priority = 200;
          label = "Loupe";
          desktop = "org.gnome.Loupe.desktop";
          cmd = ["loupe"];
        };
        pdfViewer.papers = {
          enable = hasPkg pkgs.papers;
          priority = 200;
          label = "Papers";
          desktop = "org.gnome.Papers.desktop";
          cmd = ["papers"];
        };
        audioPlayer.decibels = {
          enable = hasPkg pkgs.decibels;
          priority = 200;
          label = "Decibels";
          desktop = "org.gnome.Decibels.desktop";
          cmd = ["org.gnome.Decibels"];
        };
        videoPlayer.showtime = {
          enable = hasPkg pkgs.showtime;
          priority = 200;
          label = "Showtime";
          desktop = "org.gnome.Showtime.desktop";
          cmd = ["showtime"];
        };
      };
    };
    services = {
      desktopManager.gnome.enable = true;
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
