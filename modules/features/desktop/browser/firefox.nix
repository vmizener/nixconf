/*
  feat/desktop/browser/firefox

Firefox.

Exposes:

- flake.homeModules."feat/desktop/browser/firefox":
*/
{...}: let
  moduleName = "feat/desktop/browser/firefox";
in {
  flake.homeModules.${moduleName} = {config, ...}: {
    mod.meta.imported = [moduleName];
    programs.firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
    };
    mod."common/handlers".add.browser.firefox = {
      priority = 150;
      label = "Firefox";
      desktop = "firefox.desktop";
      cmd = ["firefox"];
    };
  };
}
