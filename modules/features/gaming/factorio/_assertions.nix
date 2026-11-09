# Per-server validation & cross-instance collision assertions for `feat/gaming/factorio`.
{
  enabledServers,
  lib,
  moduleName,
}: let
  serverItems = lib.mapAttrsToList (name: srv: {inherit name srv;}) enabledServers;
  mkCollisionAssertions = keyFn: fmtMsg: items:
    builtins.groupBy keyFn items
    |> lib.filterAttrs (_: group: builtins.length group > 1)
    |> lib.mapAttrsToList (key: entries: {
      assertion = false;
      message = fmtMsg key (lib.concatMapStringsSep ", " (e: e.name) entries);
    });
in
  (lib.concatMap (
      {
        name,
        srv,
      }: [
        {
          assertion = builtins.match "^[a-zA-Z0-9_-]+$" name != null;
          message = "mod.\"${moduleName}\".servers: invalid server name '${name}' (use alphanumeric, '_', or '-').";
        }
        {
          assertion = builtins.match "^[a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)*$" srv.stateDirName != null;
          message = "mod.\"${moduleName}\".servers.${name}.stateDirName '${srv.stateDirName}' must be a clean relative path under /var/lib.";
        }
        {
          assertion = !srv.dlc.spaceAge || (srv.dlc.elevatedRails && srv.dlc.quality);
          message = "mod.\"${moduleName}\".servers.${name}: Factorio 'space-age' requires both `dlc.elevatedRails` and `dlc.quality` to be enabled.";
        }
        {
          assertion = !srv.public || (srv.username != null && srv.tokenFile != null) || srv.extraSettingsFile != null;
          message = "mod.\"${moduleName}\".servers.${name}: `public = true` requires `username` + `tokenFile` (or `extraSettingsFile`) for Factorio matching server authentication.";
        }
        {
          assertion = !srv.rcon.enable || srv.rcon.passwordFile != null;
          message = "mod.\"${moduleName}\".servers.${name}: `rcon.enable = true` requires `rcon.passwordFile` (or top-level `rconPasswordFile`).";
        }
      ]
    )
    serverItems)
  ++ mkCollisionAssertions (e: toString e.srv.port) (
    port: names: "mod.\"${moduleName}\".servers: UDP port ${port} is assigned to multiple enabled servers: ${names}"
  )
  serverItems
  ++ mkCollisionAssertions (e: toString e.srv.rcon.port) (
    port: names: "mod.\"${moduleName}\".servers: RCON TCP port ${port} is assigned to multiple enabled servers: ${names}"
  ) (builtins.filter (e: e.srv.rcon.enable) serverItems)
  ++ mkCollisionAssertions (e: e.srv.stateDirName) (
    dir: names: "mod.\"${moduleName}\".servers: stateDirName '${dir}' is shared by multiple enabled servers: ${names}"
  )
  serverItems
