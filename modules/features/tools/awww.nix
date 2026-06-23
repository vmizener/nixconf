/*
  feat/tools/awww

Enables AWWW wallpaper service.

Exposes:

- flake.homeModules."feat/tools/awww":
*/
{inputs, ...}: {
  flake.homeModules."feat/tools/awww" = {pkgs, ...}: let
    img = ../../../assets/media/girl_leaving_apartment--zy1xjw-wallhaven.jpg;
    pkg = inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww;
  in {
    features.tools = ["awww"];
    home.packages = [pkg];
    systemd.user.services.awww = {
      Install = {
        WantedBy = ["graphical-session.target"];
      };
      Unit = {
        Description = "AWWW daemon";
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkg}/bin/awww-daemon";
        ExecStartPost = "${pkg}/bin/awww img ${img}";
        ExecStop = "${pkg}/bin/awww kill";
        Restart = "on-failure";
        RestartSec = "1";
      };
    };
  };
}
