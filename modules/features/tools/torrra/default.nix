/*
  feat/tools/torrra

Torrent search tool for CLI.

Exposes:

- flake.homeModules."feat/tools/torrra":
*/
{inputs, ...}: {
  flake.homeModules."feat/tools/torrra" = {
    config,
    pkgs,
    ...
  }: {
    features.tools = ["torrra"];
    home.packages = [inputs.torrra.packages.${pkgs.stdenv.hostPlatform.system}.default];
    xdg.configFile = {
      "torrra/config.toml".source = config.lib.file.mkOutOfStoreSymlink ./config.toml;
    };
  };
}
