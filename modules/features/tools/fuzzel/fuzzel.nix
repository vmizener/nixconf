/*
  feat/tools/fuzzel

Enables the Fuzzel launcher tool.

Exposes:

- flake.homeModules."feat/tools/fuzzel":
*/
{
  flake.homeModules."common/options" = {
  };
  flake.homeModules."feat/tools/fuzzel" = {
    config,
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [fuzzel];
    xdg.configFile = {
      "fuzzel/fuzzel.ini".source = config.lib.file.mkOutOfStoreSymLink ./fuzzel.ini;
    };
  };
}
