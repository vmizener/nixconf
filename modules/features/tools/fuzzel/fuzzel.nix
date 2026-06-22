/*
  feat/tools/fuzzel

Enables the Fuzzel Wayland app launcher tool.

Exposes:

- flake.homeModules."feat/tools/fuzzel":
*/
{
  flake.homeModules."feat/tools/fuzzel" = {
    config,
    pkgs,
    ...
  }: {
    features.tools = ["fuzzel"];
    home.packages = with pkgs; [fuzzel];
    xdg.configFile = {
      "fuzzel/fuzzel.ini".source = config.lib.file.mkOutOfStoreSymLink ./fuzzel.ini;
    };
  };
}
