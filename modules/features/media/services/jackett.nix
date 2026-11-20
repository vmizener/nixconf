/*
  feat/media/services/jackett

Jackett is an indexing service for torrent trackers.

Exposes:

- flake.nixosModules."feat/media/services/jackett":
*/
{...}: let
  moduleName = "feat/media/services/jackett";
in {
  flake.nixosModules.${moduleName} = {config, ...}: {
    mod = {
      meta.imported = [moduleName];
      "common/site/net".ports = {
        jackett.tcp = [(config.services.jackett.port or 9117)];
        flaresolverr.tcp = [config.services.flaresolverr.port];
      };
    };
    services = {
      jackett.enable = true;
      flaresolverr.enable = true;
    };
  };
}
