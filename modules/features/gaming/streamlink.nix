/*
  feat/gaming/streamlink

Streamlink is a client for reading online streams.

Exposes:

- flake.homeModules."feat/gaming/streamlink":
*/
{...}: let
  moduleName = "feat/gaming/streamlink";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    flake.imported = [moduleName];
    home.packages = with pkgs; [
      mpv
      streamlink
      streamlink-twitch-gui-bin
    ];
  };
}
