/*
  feat/gaming/streamlink

Streamlink is a client for reading online streams.

Exposes:

- flake.homeModules."feat/gaming/streamlink":
*/
{
  flake.homeModules."feat/gaming/streamlink" = {pkgs, ...}: {
    home.packages = with pkgs; [
      mpv
      streamlink
      streamlink-twitch-gui-bin
    ];
  };
}
