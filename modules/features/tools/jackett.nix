/*
  feat/tools/jackett

Jackett is an indexing service for torrent trackers.

Exposes:

- flake.nixosModules."feat/tools/jackett":
*/
let
  moduleName = "feat/tools/jackett";
in {
  flake.nixosModules.${moduleName} = {...}: {
    flake.imported = [moduleName];
    services = {
      jackett.enable = true;
      flaresolverr.enable = true;
    };
  };
}
