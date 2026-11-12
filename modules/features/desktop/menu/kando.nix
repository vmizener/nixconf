/*
  feat/desktop/menu/kando

Enables the Kando menu tool.

Exposes:

- flake.homeModules."feat/desktop/menu/kando":
*/
let
  moduleName = "feat/desktop/menu/kando";
in {
  flake.homeModules.${moduleName} = {
    lib,
    pkgs,
    ...
  }: {
    mod.meta.imported = [moduleName];
    home.packages = with pkgs; [kando];
    systemd.user.services.kando = {
      Install = {
        WantedBy = ["graphical-session.target"];
      };
      Unit = {
        Description = "Kando daemon";
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.kando}";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };
    mod."common/handlers".add.menu.kando = {
      priority = 100;
      label = "Kando";
      cmd = ["kando" "--menu" "Main Menu"];
    };
  };
}
