# Substitutes server-specific store paths and flags into `./pre-start.sh`.
{
  lib,
  name,
  pkgs,
  runtimeDir,
  savePath,
  srv,
  stateDir,
}:
pkgs.replaceVars ./pre-start.sh {
  FACTORIO_BIN = lib.getExe srv.package;
  STATE_DIR = stateDir;
  RUNTIME_DIR = runtimeDir;
  SAVE_PATH = savePath;

  CONFIG_FILE = pkgs.writeText "factorio-${name}.conf" ''
    use-system-read-write-data-directories=true
    [path]
    read-data=${srv.package}/share/factorio/data
    write-data=${stateDir}
  '';

  MOD_DIR =
    if srv.mods == []
    then ""
    else "${pkgs.factorio-utils.mkModDirDrv srv.mods null}";
  MODS_DAT =
    if srv.modsDat == null
    then ""
    else "${srv.modsDat}";

  MOD_LIST_FILE =
    {
      mods =
        (
          {
            "base" = true;
            "elevated-rails" = srv.dlc.elevatedRails;
            "quality" = srv.dlc.quality;
            "space-age" = srv.dlc.spaceAge;
          }
          // srv.extraModList
        )
        |> lib.mapAttrsToList (modName: enabled: {
          name = modName;
          inherit enabled;
        });
    }
    |> builtins.toJSON
    |> pkgs.writeText "factorio-${name}-mod-list.json";

  BASE_SETTINGS_FILE =
    (
      {
        name = srv.gameName;
        inherit (srv) description tags username;
        max_players = srv.maxPlayers;
        visibility = {inherit (srv) public lan;};
        require_user_verification = srv.requireUserVerification;
        max_upload_in_kilobytes_per_second = 0;
        max_upload_slots = 5;
        minimum_latency_in_ticks = 0;
        ignore_player_limit_for_returning_players = false;
        allow_commands = srv.allowCommands;
        autosave_interval = srv.autosaveInterval;
        autosave_slots = srv.autosaveSlots;
        afk_autokick_interval = 0;
        auto_pause = srv.autoPause;
        only_admins_can_pause_the_game = true;
        autosave_only_on_server = true;
        non_blocking_saving = srv.nonBlockingSaving;
      }
      // srv.extraSettings
      |> lib.filterAttrsRecursive (_: v: v != null)
      |> builtins.toJSON
    )
    |> pkgs.writeText "factorio-${name}-server-settings.json";

  MAP_PRESET =
    if srv.mapPreset == null
    then ""
    else srv.mapPreset;
  MAP_GEN_SEED =
    if srv.mapGenSeed == null
    then ""
    else toString srv.mapGenSeed;
  MAP_GEN_SETTINGS =
    if srv.mapGenSettings == {}
    then ""
    else "${pkgs.writeText "factorio-${name}-map-gen-settings.json" (builtins.toJSON srv.mapGenSettings)}";
  MAP_SETTINGS =
    if srv.mapSettings == {}
    then ""
    else "${pkgs.writeText "factorio-${name}-map-settings.json" (builtins.toJSON srv.mapSettings)}";
}
