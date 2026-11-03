/*
  feat/tools/fuzzel

Enables the Fuzzel Wayland app launcher tool.

Exposes:

- flake.homeModules."feat/tools/fuzzel":
*/
let
  moduleName = "feat/tools/fuzzel";
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
  };
}
