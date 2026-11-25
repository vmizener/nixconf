/*
  feat/media/playback/spotify

Enables the Spotify desktop client.

Exposes:

- flake.homeModules."feat/media/playback/spotify":
*/
{...}: let
  moduleName = "feat/media/playback/spotify";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    home.packages = [pkgs.spotify];
  };
}
