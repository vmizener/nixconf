/*
  feat/sync/maestral

Enables the Maeastral 3rd-party Dropbox client.

Exposes:

- flake.homeModules."feat/sync/maestral":
*/
let
  moduleName = "feat/sync/maestral";
in {
  flake.homeModules."common/options" = {
    config,
    lib,
    ...
  }: {
    options.mod.${moduleName} = {
      maestral_path = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/Dropbox";
        defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Dropbox"'';
        description = "Directory to sync files to.";
      };
      accountIdSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "services/maestral/account_id";
        description = "Key in `sops.secrets` providing the Dropbox `account_id` for the default auth template (`null` disables the default `sops` secret and template).";
      };
      extraConfigFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional runtime INI file (e.g. from `sops.templates`) merged into `maestral.ini` on startup, overriding the default `accountIdSecret` template.";
      };
    };
  };
  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    configPath = "${config.xdg.configHome}/maestral/maestral.ini";
    useDefaultTemplate = cfg.accountIdSecret != null && cfg.extraConfigFile == null;
    mkMaestralIni = accountIdLine:
      pkgs.replaceVars ./maestral.ini {
        MAESTRAL_PATH = cfg.maestral_path;
        MAESTRAL_ACCOUNT_ID = accountIdLine;
      };
    renderedConfig =
      if useDefaultTemplate
      then config.sops.templates."maestral.ini".path
      else "${mkMaestralIni ""}";
    usesSops = config.sops.secrets != {} || config.sops.templates != {};
    crudiniBin = lib.getExe pkgs.crudini;
  in {
    mod.meta.imported = [moduleName];
    home.packages = with pkgs; [
      maestral
      maestral-gui
    ];

    sops = {
      secrets = lib.mkIf useDefaultTemplate {
        ${cfg.accountIdSecret} = {};
      };
      templates = lib.mkIf useDefaultTemplate {
        "maestral.ini".file =
          mkMaestralIni "account_id = ${config.sops.placeholder.${cfg.accountIdSecret}}";
      };
    };

    systemd.user.services.maestral = {
      Install = {
        WantedBy = ["default.target"];
      };
      Unit = {
        Description = "Maestral daemon";
        After = lib.optional usesSops "sops-nix.service";
        Requires = lib.optional usesSops "sops-nix.service";
      };
      Service = {
        Type = "notify";
        NotifyAccess = "exec";
        PermissionsStartOnly = true;
        ExecStartPre = pkgs.writeShellScript "maestral-merge-config.sh" (
          ''
            set -euo pipefail
            mkdir -p "$(dirname ${lib.escapeShellArg configPath})"
            if [ -f ${lib.escapeShellArg configPath} ] && [ ! -L ${lib.escapeShellArg configPath} ]; then
              chmod 0600 ${lib.escapeShellArg configPath}
              # Use crudini to merge ini files
              ${crudiniBin} --merge ${lib.escapeShellArg configPath} < ${lib.escapeShellArg renderedConfig}
            else
              rm -f ${lib.escapeShellArg configPath}
              install -m 0600 ${lib.escapeShellArg renderedConfig} ${lib.escapeShellArg configPath}
            fi
          ''
          + lib.optionalString (cfg.extraConfigFile != null) ''
            ${crudiniBin} --merge ${lib.escapeShellArg configPath} < ${lib.escapeShellArg (toString cfg.extraConfigFile)}
          ''
        );
        ExecStart = "${lib.getExe pkgs.maestral} start --foreground";
        ExecStop = "${lib.getExe pkgs.maestral} stop";
        ExecStopPost = pkgs.writeShellScript "maestral-stop-post.sh" ''
          if [ "$SERVICE_RESULT" != "success" ]; then
            ${pkgs.libnotify}/bin/notify-send 'Maestral daemon failed'
          fi
        '';
        WatchdogSec = "30s";
        Environment = "PYTHONOPTIMIZE=2 LC_CTYPE=UTF-8";
      };
    };
    systemd.user.services.maestral-gui = {
      Install = {
        WantedBy = ["graphical-session.target"];
      };
      Unit = {
        Description = "Maestral GUI";
        Requires = ["maestral.service"];
        After = [
          "graphical-session.target"
          "maestral.service"
        ];
        PartOf = [
          "graphical-session.target"
          "maestral.service"
        ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.maestral-gui}/bin/maestral_qt";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };
  };
}
