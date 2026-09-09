/*
  feat/browser/firefox

Firefox.

Exposes:

- flake.homeModules."feat/browser/firefox":
*/
{...}: let
  moduleName = "feat/browser/firefox";
in {
  flake.homeModules.${moduleName} = {config, ...}: {
    flake.imported = [moduleName];
    programs.firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
    };
    features.system.mime.add.browser."firefox.desktop" = 150;
  };
}
