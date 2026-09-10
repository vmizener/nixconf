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
    mod.imported = [moduleName];
    programs.firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
    };
    mod."feat/system/mime".add.browser."firefox.desktop" = 150;
  };
}
