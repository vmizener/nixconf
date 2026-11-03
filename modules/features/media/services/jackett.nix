/*
  feat/media/services/jackett

Jackett is an indexing service for torrent trackers.

Exposes:

- flake.nixosModules."feat/media/services/jackett":
*/
let
  moduleName = "feat/media/services/jackett";
in {
  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
    services = {
      jackett.enable = true;
      flaresolverr.enable = true;
    };
  };
}
