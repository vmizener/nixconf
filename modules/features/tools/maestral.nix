/*
  feat/tools/maestral

Enables the Maeastral 3rd-party Dropbox client.

Exposes:

- flake.homeModules."feat/tools/maestral":
*/
{
  flake.homeModules."feat/tools/maestral" = {
    lib,
    pkgs,
    ...
  }: {
    features.tools = ["maestral"];
    home.packages = with pkgs; [
      maestral
      maestral-gui
    ];
    systemd.user.services.maestral = {
      Install = {
        WantedBy = ["default.target"];
      };
      Unit = {
        Description = "Maestral daemon";
      };
      Service = {
        Type = "notify";
        NotifyAccess = "exec";
        PermissionsStartOnly = true;
        ExecStart = "${lib.getExe pkgs.maestral} start --foreground";
        ExecStop = "${lib.getExe pkgs.maestral} stop";
        ExecStopPost = "${pkgs.writeShellScript "maestral-stop-post.sh" ''
          if [ $SERVICE_RESULT != success ]; then
            ${pkgs.libnotify}/bin/notify-send 'Maestral daemon failed'
          fi
        ''}";
        WatchdogSec = "30s";
        Environment = "PYTHONOPTIMIZE=2 LC_CTYPE=UTF-8";
      };
    };
    systemd.user.services.maestral-gui = {
      Install = {
        WantedBy = ["default.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.maestral-gui}/bin/maestral_qt";
        ExecStop = "kill -TERM $MAINPID";
        ExecStopPost = "kill -KILL $MAINPID";
        TimeoutStopSec = "1";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };
  };
}
