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
    mod."common/handlers".add.launcher.fuzzel = {
      priority = 150;
      label = "Fuzzel";
      cmd = ["fuzzel"];
    };
  };
}
