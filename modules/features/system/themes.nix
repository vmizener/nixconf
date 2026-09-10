/*
  feat/system/themes

Adds system themes.

Exposes:

- flake.homeModules."feat/system/theme":
- flake.nixosModules."feat/system/theme":
*/
{...}: let
  moduleName = "feat/system/theme";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: let
    theme = "Breeze-Dark";
    iconTheme = "cat-mocha-lavender"; # For icons, e.g. in pcmanfm-qt
    cursorTheme = "mochaLight";
    cursorSize = 16;
  in {
    mod.imported = [moduleName];
    gtk = {
      enable = true;
      theme.name = theme;
      iconTheme.name = iconTheme;
      cursorTheme = {
        size = cursorSize;
        name = cursorTheme;
      };
      gtk3 = {
        bookmarks = [
          "file:///tmp"
        ];
        extraConfig.gtk-application-prefer-dark-theme = true;
      };
      gtk4.theme = null;
    };
  };
  flake.nixosModules.${moduleName} = {pkgs, ...}: {
    mod.imported = [moduleName];
    environment.systemPackages = with pkgs; [
      # Themes
      kdePackages.breeze-gtk
      kdePackages.breeze-icons
      kdePackages.breeze.qt5
      kdePackages.breeze
      # catppuccin-cursors # Mouse cursor theme
      # catppuccin-papirus-folders # Icon theme, e.g. for pcmanfm-qt
      papirus-folders # For the catppucing stuff work
    ];
    qt = {
      enable = true;
      platformTheme = "kde";
    };
  };
}
