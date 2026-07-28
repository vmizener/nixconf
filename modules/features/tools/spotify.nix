/*
  feat/tools/spotify

Enables Spotify service.

Exposes:

- flake.homeModules."feat/tools/spotify":
*/
{
  flake.homeModules."feat/tools/spotify" = {pkgs, ...}: {
    home.packages = [pkgs.spotify];
    services.spotifyd.enable = true;
  };
}
