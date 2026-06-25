/*
  feat/tools/kando

Enables the Kando menu tool.

Exposes:

- flake.homeModules."feat/tools/kando":
*/
{
  flake.homeModules."feat/tools/kando" = {
    lib,
    pkgs,
    ...
  }: {
    features.tools = ["kando"];
    home.packages = with pkgs; [kando];
    systemd.user.services.kando = {
      Install = {
        WantedBy = ["graphical-session.target"];
      };
      Unit = {
        Description = "Kando daemon";
        After = ["graphical-session.target"];
        WantedBy = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.kando}";
        ExecStop = "kill -TERM $MAINPID";
        ExecStopPost = "kill -KILL $MAINPID";
        TimeoutStopSec = "1";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };
  };
}
