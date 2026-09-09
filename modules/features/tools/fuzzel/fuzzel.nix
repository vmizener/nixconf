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
    flake.imported = [moduleName];
    home.packages = with pkgs; [fuzzel];
    xdg.configFile = {
      "fuzzel/fuzzel.ini".source = config.lib.file.mkOutOfStoreSymLink ./fuzzel.ini;
    };
  };
}
