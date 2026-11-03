/*
  feat/media/playback/streamlink

Streamlink is a client for reading online streams.

Exposes:

- flake.homeModules."feat/media/playback/streamlink":
*/
{...}: let
  moduleName = "feat/media/playback/streamlink";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    home.packages = with pkgs; [
      mpv
      streamlink
      streamlink-twitch-gui-bin
    ];
  };
}
