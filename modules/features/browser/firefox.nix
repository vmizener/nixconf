/*
  feat/browser/firefox

Firefox.

Exposes:

- flake.homeModules."feat/browser/firefox":
*/
{
  flake.homeModules."feat/browser/firefox" = {
    config,
    lib,
    ...
  }: {
    programs.firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
    };
    features.system.mime.categories.browsers = lib.mkIf config.features.system.mime.enable (lib.mkOrder 150 ["firefox.desktop"]);
  };
}
