/*
  feat/sync/maestral

Enables the Maeastral 3rd-party Dropbox client.

Exposes:

- flake.homeModules."feat/sync/maestral":
*/
{...}: let
  moduleName = "feat/sync/maestral";
in {
  flake.homeModules."common/options" = {
    config,
    lib,
    ...
  }: {
    options.mod.${moduleName} = {
      maestralPath = lib.mkOption {
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
    osConfig ? null,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    configPath = "${config.xdg.configHome}/maestral/maestral.ini";
    useDefaultTemplate = cfg.accountIdSecret != null && cfg.extraConfigFile == null;
    mkMaestralIni = accountIdLine:
      pkgs.replaceVars ./maestral.ini {
        MAESTRAL_PATH = cfg.maestralPath;
        MAESTRAL_ACCOUNT_ID = accountIdLine;
      };
    renderedConfig =
      if useDefaultTemplate
      then config.sops.templates."maestral.ini".path
      else "${mkMaestralIni ""}";
    usesSops = config.sops.secrets != {} || config.sops.templates != {};
  in {
    mod.meta.imported = [moduleName];

    assertions = lib.optional (osConfig != null) {
      assertion = config.mod."common/keyring".enable;
      message = ''flake.homeModules."${moduleName}" requires an active keyring provider in mod."common/keyring" (e.g. flake.nixosModules."feat/system/keyring") for SecretService storage.'';
    };

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
        ExecStartPre = "${pkgs.runtimeShell} ${pkgs.replaceVars ./merge-config.sh {
          CONFIG_PATH = configPath;
          RENDERED_CONFIG = renderedConfig;
          EXTRA_CONFIG_FILE =
            if cfg.extraConfigFile != null
            then toString cfg.extraConfigFile
            else "";
          CRUDINI_BIN = lib.getExe pkgs.crudini;
        }}";
        ExecStart = "${lib.getExe pkgs.maestral} start --foreground";
        ExecStop = "${lib.getExe pkgs.maestral} stop";
        ExecStopPost = "${pkgs.runtimeShell} ${pkgs.replaceVars ./stop-post.sh {
          NOTIFY_SEND_BIN = "${pkgs.libnotify}/bin/notify-send";
        }}";
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
