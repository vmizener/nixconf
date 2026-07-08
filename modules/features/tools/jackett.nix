/*
  feat/tools/jackett

Jackett is an indexing service for torrent trackers.

Exposes:

- flake.nixosModules."feat/tools/jackett":
*/
{
  flake.nixosModules."feat/tools/jackett" = {
    ...
  }: {
    features.tools = ["jackett"];
    services.jackett = {
      enable = true;
    };
  };
}
