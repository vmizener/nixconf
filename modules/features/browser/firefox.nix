/*
  feat/browser/firefox

Firefox.

Exposes:

- flake.homeModules."feat/browser/firefox":
*/
{
  flake.homeModules."feat/browser/firefox" = {config, ...}: {
    programs.firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
    };
    features.system.mime.add.browser."firefox.desktop" = 150;
  };
}
