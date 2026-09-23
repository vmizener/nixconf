/*
  feat/tools/maestral

Enables the Maeastral 3rd-party Dropbox client.

Exposes:

- flake.homeModules."feat/tools/maestral":
*/
let
  moduleName = "feat/tools/maestral";
in {
  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    configPath = "${config.xdg.configHome}/maestral/maestral.ini";
    templatePath = config.sops.templates."maestral.ini".path;
  in {
    mod.imported = [moduleName];
    home.packages = with pkgs; [
      maestral
      maestral-gui
    ];

    sops = {
      secrets."maestral/account_id" = {};
      templates."maestral.ini".file = pkgs.replaceVars ./maestral.ini {
        HOME = config.home.homeDirectory;
        MAESTRAL_ACCOUNT_ID = config.sops.placeholder."maestral/account_id";
      };
    };

    systemd.user.services.maestral = {
      Install = {
        WantedBy = ["default.target"];
      };
      Unit = {
        Description = "Maestral daemon";
        After = ["sops-nix.service"];
        Requires = ["sops-nix.service"];
      };
      Service = {
        Type = "notify";
        NotifyAccess = "exec";
        PermissionsStartOnly = true;
        ExecStartPre = pkgs.writeShellScript "maestral-merge-config.sh" ''
          mkdir -p "$(dirname "${configPath}")"
          if [ -f "${configPath}" ] && [ ! -L "${configPath}" ]; then
            # Use crudini to merge ini files
            ${lib.getExe pkgs.crudini} --merge "${configPath}" < "${templatePath}"
          else
            rm -f "${configPath}"
            cp "${templatePath}" "${configPath}"
          fi
          chmod 0600 "${configPath}"
        '';
        ExecStart = "${lib.getExe pkgs.maestral} start --foreground";
        ExecStop = "${lib.getExe pkgs.maestral} stop";
        ExecStopPost = pkgs.writeShellScript "maestral-stop-post.sh" ''
          if [ $SERVICE_RESULT != success ]; then
            ${pkgs.libnotify}/bin/notify-send 'Maestral daemon failed'
          fi
        '';
        WatchdogSec = "30s";
        Environment = "PYTHONOPTIMIZE=2 LC_CTYPE=UTF-8";
      };
    };
    systemd.user.services.maestral-gui = {
      Install = {
        WantedBy = [
          "default.target"
          "maestral.service"
        ];
      };
      Unit = {
        Requires = ["maestral.service"];
        After = ["maestral.service"];
        PartOf = ["maestral.service"];
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
