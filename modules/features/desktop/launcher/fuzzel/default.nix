/*
  feat/desktop/launcher/fuzzel

Enables the Fuzzel Wayland app launcher tool.

Exposes:

- flake.homeModules."feat/desktop/launcher/fuzzel":
*/
let
  moduleName = "feat/desktop/launcher/fuzzel";
in {
  flake.homeModules.${moduleName} = {
    config,
    pkgs,
    ...
  }: {
    mod.meta.imported = [moduleName];
    home.packages = with pkgs; [fuzzel];
    xdg.configFile = {
      "fuzzel/fuzzel.ini".source = config.mod.meta.link ./fuzzel.ini;
    };
    xdg.desktopEntries.fuzzel = {
      name = "Fuzzel";
      exec = "fuzzel";
      noDisplay = true;
    };
    mod."common/mime".add.launcher."fuzzel.desktop" = 150;
  };
}
