/*
  feat/media/playback/spotify

Enables Spotify service.

Exposes:

- flake.homeModules."feat/media/playback/spotify":
*/
{...}: let
  moduleName = "feat/media/playback/spotify";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    home.packages = [pkgs.spotify];
    services.spotifyd.enable = true;
  };
}
