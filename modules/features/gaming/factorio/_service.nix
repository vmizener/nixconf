# Builds a hardened `systemd.services."factorio-<name>"` unit definition.
{
  extraAdmins,
  lib,
  name,
  pkgs,
  srv,
}: let
  stateDir = "/var/lib/${srv.stateDirName}";
  runtimeName = "factorio/${name}";
  runtimeDir = "/run/${runtimeName}";
  savePath = "${stateDir}/saves/${srv.saveName}.zip";

  credentials =
    lib.optional (srv.tokenFile != null) "token:${srv.tokenFile}"
    ++ lib.optional (srv.gamePasswordFile != null) "game-password:${srv.gamePasswordFile}"
    ++ lib.optional (srv.rcon.enable && srv.rcon.passwordFile != null) "rcon-password:${srv.rcon.passwordFile}"
    ++ lib.optional (srv.extraSettingsFile != null) "extra-settings:${srv.extraSettingsFile}";
in {
  description = "Factorio headless server (${name})";
  wantedBy = ["multi-user.target"];
  wants = ["network-online.target"];
  after =
    ["network-online.target"]
    ++ lib.optional (credentials != []) "sops-install-secrets.service";
  path = [
    pkgs.findutils
    pkgs.jq
  ];

  serviceConfig = {
    Type = "simple";
    User = "factorio";
    Group = "factorio";
    Restart = "on-failure";
    RestartSec = "5s";
    KillSignal = "SIGINT";
    TimeoutStopSec = "2min";
    StateDirectory = srv.stateDirName;
    StateDirectoryMode = "0770";
    RuntimeDirectory = runtimeName;
    RuntimeDirectoryMode = "0700";
    UMask = "0007";
    LoadCredential = credentials;

    ExecStartPre = let
      preStartScript = import ./_pre-start.nix {
        inherit lib name pkgs runtimeDir savePath srv stateDir;
      };
    in "${lib.getExe pkgs.bash} ${preStartScript}";

    ExecStart = let
      allAdmins = lib.unique (extraAdmins ++ srv.admins);
      writeList = suffix: items:
        pkgs.writeText "factorio-${name}-${suffix}.json" (builtins.toJSON items);
      startArgs =
        [
          (lib.getExe srv.package)
          "--config=${runtimeDir}/factorio.conf"
          "--port=${toString srv.port}"
          "--bind=${srv.bind}"
          "--server-settings=${runtimeDir}/server-settings.json"
          (
            if srv.loadLatestSave
            then "--start-server-load-latest"
            else "--start-server=${savePath}"
          )
        ]
        ++ lib.optional (allAdmins != []) "--server-adminlist=${writeList "admins" allAdmins}"
        ++ lib.optionals (srv.allowedPlayers != []) [
          "--server-whitelist=${writeList "whitelist" srv.allowedPlayers}"
          "--use-server-whitelist"
        ]
        ++ srv.extraArgs;
    in
      if !srv.rcon.enable
      then lib.escapeShellArgs startArgs
      else
        toString (pkgs.writeShellScript "factorio-${name}-start" ''
          set -euo pipefail
          rcon_pw="$(tr -d '\r\n' < "$CREDENTIALS_DIRECTORY/rcon-password")"
          exec ${lib.escapeShellArgs startArgs} \
            ${lib.escapeShellArg "--rcon-bind=${srv.rcon.bind}:${toString srv.rcon.port}"} \
            "--rcon-password=$rcon_pw"
        '');

    # Hardening
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectControlGroups = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
    ];
    RestrictRealtime = true;
    RestrictNamespaces = true;
    MemoryDenyWriteExecute = true;
  };
}
