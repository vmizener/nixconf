/*
  feat/system/theme

Configures GTK, icon, cursor, and Qt themes across NixOS and Home-Manager.

Set mod."feat/system/theme".themes to select installed theme collections.
Available collections: ["breeze"] (default is all)

Exposes:

- flake.nixosModules."common/options" (options.mod."feat/system/theme")
- flake.homeModules."common/options" (options.mod."feat/system/theme")
- flake.nixosModules."feat/system/theme":
  - Installs selected theme collections system-wide and enables Qt KDE/Breeze integration.
- flake.homeModules."feat/system/theme":
  - Installs selected theme collections (deduplicated against NixOS `feat/system/theme`)
  - Configures GTK theme, icon theme, and cursor theme.
*/
{lib, ...}: let
  moduleName = "feat/system/theme";

  themeCollections = import ./_themes.nix;
  allThemes = builtins.attrNames (themeCollections null);

  selectThemes = pkgs: names:
    lib.concatMap (name: (themeCollections pkgs).${name}) (lib.unique names);

  mkThemeOptions = osTheme: {
    themes = lib.mkOption {
      type = lib.types.listOf (lib.types.enum allThemes);
      default =
        if osTheme != null
        then osTheme.themes
        else allThemes;
      defaultText = lib.literalExpression (builtins.toJSON allThemes);
      description = "Theme collections from `_themes.nix` to install.";
    };
    gtkTheme = lib.mkOption {
      type = lib.types.str;
      default =
        if osTheme != null
        then osTheme.gtkTheme
        else "Breeze-Dark";
      description = "Active GTK widget theme name.";
    };
    iconTheme = lib.mkOption {
      type = lib.types.str;
      default =
        if osTheme != null
        then osTheme.iconTheme
        else "breeze-dark";
      description = "Active icon theme name.";
    };
    cursorTheme = lib.mkOption {
      type = lib.types.str;
      default =
        if osTheme != null
        then osTheme.cursorTheme
        else "breeze_cursors";
      description = "Active cursor theme name.";
    };
    cursorSize = lib.mkOption {
      type = lib.types.ints.positive;
      default =
        if osTheme != null
        then osTheme.cursorSize
        else 16;
      description = "Active cursor size in pixels.";
    };
  };
in {
  flake.nixosModules."common/options" = {...}: {
    options.mod.${moduleName} = mkThemeOptions null;
  };

  flake.homeModules."common/options" = {osConfig ? null, ...}: let
    osTheme =
      if osConfig != null && osConfig.mod.meta.has moduleName
      then osConfig.mod.${moduleName}
      else null;
  in {
    options.mod.${moduleName} = mkThemeOptions osTheme;
  };

  flake.homeModules.${moduleName} = {
    config,
    osConfig ? null,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    osThemes =
      if osConfig != null && osConfig.mod.meta.has moduleName
      then osConfig.mod.${moduleName}.themes
      else [];
    hmThemes = builtins.filter (t: !(builtins.elem t osThemes)) cfg.themes;
  in {
    mod.meta.imported = [moduleName];
    home.packages = selectThemes pkgs hmThemes;
    gtk = {
      enable = true;
      theme.name = cfg.gtkTheme;
      iconTheme.name = cfg.iconTheme;
      cursorTheme = {
        name = cfg.cursorTheme;
        size = cfg.cursorSize;
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

  flake.nixosModules.${moduleName} = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.meta.imported = [moduleName];
    environment.systemPackages = selectThemes pkgs cfg.themes;
    qt = lib.mkIf (builtins.elem "breeze" cfg.themes) {
      enable = true;
      platformTheme = lib.mkDefault "kde";
    };
  };
}
