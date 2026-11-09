# Submodule options for `mod."feat/gaming/factorio".servers.<name>`.
{
  cfg,
  lib,
  moduleName,
}: {name, ...}: {
  options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable this Factorio server instance.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = cfg.package;
      defaultText = lib.literalExpression "config.mod.\"${moduleName}\".package";
      description = "Factorio headless package for this instance (e.g. `pkgs.factorio-headless-experimental`).";
    };

    # Network & firewall
    bind = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "IP address the Factorio UDP game socket binds to.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 34197;
      description = "UDP port for this Factorio server instance (must be unique per enabled server).";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = cfg.openFirewall;
      defaultText = lib.literalExpression "config.mod.\"${moduleName}\".openFirewall";
      description = "Whether to open `port` (UDP) in the firewall.";
    };

    # Server browser metadata & player access
    gameName = lib.mkOption {
      type = lib.types.str;
      default = "Factorio: ${name}";
      description = "Server name displayed in the Factorio multiplayer browser.";
    };
    description = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Server description displayed in the Factorio multiplayer browser.";
    };
    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Server browser tags.";
    };
    maxPlayers = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "Maximum concurrent players (`0` means unlimited).";
    };
    public = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Publish this server on the official Factorio matching server (requires `username` + `tokenFile` or `extraSettingsFile`).";
    };
    lan = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Broadcast this server on the local network (LAN).";
    };
    requireUserVerification = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require connecting clients to verify ownership of a valid factorio.com account.";
    };
    admins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Admin player usernames for this instance (merged with top-level `extraAdmins`).";
    };
    allowedPlayers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Player whitelist. When non-empty, only listed usernames may connect (`--use-server-whitelist`).";
    };
    allowCommands = lib.mkOption {
      type = lib.types.enum ["true" "false" "admins-only"];
      default = "admins-only";
      description = "Who is permitted to execute Lua console commands (`allow_commands` in `server-settings.json`).";
    };

    # Runtime credentials & secrets (loaded via systemd LoadCredential; never stored in /nix/store)
    username = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = cfg.username;
      defaultText = lib.literalExpression "config.mod.\"${moduleName}\".username";
      description = "Factorio account username for public server registration.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = cfg.tokenFile;
      defaultText = lib.literalExpression "config.mod.\"${moduleName}\".tokenFile";
      description = "Path to a file containing the Factorio service token from factorio.com/profile (e.g. `config.sops.secrets.\"factorio/token\".path`).";
    };
    gamePasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = cfg.gamePasswordFile;
      defaultText = lib.literalExpression "config.mod.\"${moduleName}\".gamePasswordFile";
      description = "Path to a file containing `game_password` required to join.";
    };
    extraSettingsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional runtime JSON file (e.g. from `sops.templates`) deep-merged into `server-settings.json` on startup.";
    };

    # Space Age built-in DLC & custom mods
    dlc = {
      spaceAge = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the built-in `space-age` expansion mod (`elevated-rails` and `quality` must also remain enabled).";
      };
      elevatedRails = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the built-in `elevated-rails` expansion mod.";
      };
      quality = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the built-in `quality` expansion mod.";
      };
    };
    mods = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Declarative Factorio mod derivations (compatible with `pkgs.factorio-utils.modDrv`) symlinked into this server's `mods/` directory.";
    };
    extraModList = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "Additional `mod-list.json` `name -> enabled` entries merged on service start.";
    };
    modsDat = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional `mod-settings.dat` file copied into the server's `mods/` directory before start.";
    };

    # Saves, autosaves & initial map generation
    stateDirName = lib.mkOption {
      type = lib.types.str;
      default = "factorio/${name}";
      description = "Relative directory under `/var/lib` storing saves, logs, and mods (`/var/lib/<stateDirName>`).";
    };
    saveName = lib.mkOption {
      type = lib.types.str;
      default = name;
      description = "Canonical save name (`saves/<saveName>.zip`). Automatically created via `--create` on first start if absent.";
    };
    loadLatestSave = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start with `--start-server-load-latest` so recent autosaves are loaded after crashes instead of reverting to `<saveName>.zip`.";
    };
    autosaveInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Autosave interval in minutes.";
    };
    autosaveSlots = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Number of rotating autosave slots kept by the server.";
    };
    autoPause = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Pause game simulation automatically while zero players are connected.";
    };
    nonBlockingSaving = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Fork in the background during autosaves on Linux to avoid save lag spikes on large multi-planet Space Age worlds.";
    };
    mapPreset = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "rail-world";
      description = "Optional Factorio map generation preset passed via `--preset` when creating `<saveName>.zip`.";
    };
    mapGenSeed = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = "Optional world seed passed via `--map-gen-seed` when creating `<saveName>.zip`.";
    };
    mapGenSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Declarative `map-gen-settings.json` attributes passed via `--map-gen-settings` during initial `--create` (`{}` uses Factorio defaults).";
    };
    mapSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Declarative `map-settings.json` attributes passed via `--map-settings` during initial `--create` (`{}` uses Factorio defaults).";
    };

    # RCON
    rcon = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the Factorio RCON TCP management interface for this server.";
      };
      bind = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address for the RCON listener.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 27015;
        description = "TCP port for the RCON listener (must be unique across RCON-enabled servers).";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to open `rcon.port` (TCP) in the firewall.";
      };
      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = cfg.rconPasswordFile;
        defaultText = lib.literalExpression "config.mod.\"${moduleName}\".rconPasswordFile";
        description = "Path to a file containing the RCON password.";
      };
    };

    # Escape hatches
    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Additional fields merged into `server-settings.json`.";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra command-line flags appended to the `factorio` server invocation.";
    };
  };
}
