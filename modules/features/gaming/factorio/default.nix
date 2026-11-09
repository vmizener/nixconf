/*
  feat/gaming/factorio

Declarative headless Factorio (Space Age) dedicated server manager
supporting multiple server instances per NixOS host.

Note: Wube's free `factorio-headless` package already ships the built-in
`space-age`, `elevated-rails`, and `quality` expansion data—no Factorio account
credentials are required at Nix build time. Credentials (`username` + `tokenFile`)
are only required at runtime when publishing to the public Factorio server browser
(`public = true`), and are injected via systemd `LoadCredential` so secrets never
enter `/nix/store`.

Example host configuration:

  sops.secrets = {
    "factorio/token" = {};
    "factorio/game_password" = {};
  };

  mod."feat/gaming/factorio" = {
    username = "my-factorio-user";
    tokenFile = config.sops.secrets."factorio/token".path;
    extraAdmins = ["my-factorio-user"];

    servers.my-server = {
      port = 34197;
      gameName = "My Server";
      description = "Factorio: Space Age dedicated server";
      public = true;
      gamePasswordFile = config.sops.secrets."factorio/game_password".path;
      mapPreset = "rail-world";
      mapGenSettings = {
        starting_area = 1.5;
      };
    };
  };

Exposes:

- flake.nixosModules."feat/gaming/factorio":
*/
{...}: let
  moduleName = "feat/gaming/factorio";
in {
  flake.nixosModules."common/options" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    options.mod.${moduleName} = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.factorio-headless;
        defaultText = lib.literalExpression "pkgs.factorio-headless";
        description = "Default Factorio headless server package (`pkgs.factorio-headless` or `pkgs.factorio-headless-experimental`).";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether enabled servers open their UDP `port` in the firewall by default.";
      };
      extraAdmins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Admin player usernames applied across every Factorio server on this host.";
      };
      username = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default factorio.com account username shared across public servers on this host.";
      };
      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Default Factorio service token file shared across public servers (e.g. `config.sops.secrets.\"factorio/token\".path`).";
      };
      gamePasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Default join password file shared across servers unless overridden per server.";
      };
      rconPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Default RCON password file shared across RCON-enabled servers unless overridden per server.";
      };
      servers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (import ./_server-options.nix {
            inherit cfg lib moduleName;
          })
        );
        default = {};
        description = "Attribute set of headless Factorio server instances (`factorio-<name>.service`).";
      };
    };
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    enabledServers = lib.filterAttrs (_: srv: srv.enable) cfg.servers;
  in {
    mod.meta.imported = [moduleName];

    assertions = import ./_assertions.nix {
      inherit enabledServers lib moduleName;
    };

    users = lib.mkIf (enabledServers != {}) {
      groups.factorio = {};
      users.factorio = {
        isSystemUser = true;
        group = "factorio";
        home = "/var/lib/factorio";
        description = "Factorio headless server user";
      };
    };

    systemd.services =
      lib.mapAttrs' (
        name: srv:
          lib.nameValuePair "factorio-${name}" (import ./_service.nix {
            inherit (cfg) extraAdmins;
            inherit lib name pkgs srv;
          })
      )
      enabledServers;

    networking.firewall = lib.mkIf (enabledServers != {}) {
      allowedUDPPorts =
        builtins.attrValues enabledServers
        |> builtins.filter (srv: srv.openFirewall)
        |> map (srv: srv.port);
      allowedTCPPorts =
        builtins.attrValues enabledServers
        |> builtins.filter (srv: srv.rcon.enable && srv.rcon.openFirewall)
        |> map (srv: srv.rcon.port);
    };
  };
}
