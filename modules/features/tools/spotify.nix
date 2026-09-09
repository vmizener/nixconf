/*
  feat/tools/spotify

Enables Spotify service.

Exposes:

- flake.homeModules."feat/tools/spotify":
*/
{...}: let
  moduleName = "feat/tools/spotify";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    flake.imported = [moduleName];
    home.packages = [pkgs.spotify];
    services.spotifyd.enable = true;
  };
}
