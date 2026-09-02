/*
  feat/tools/awww

Enables AWWW wallpaper service.

Exposes:

- flake.homeModules."feat/tools/awww":
*/
{inputs, ...}: {
  flake.homeModules."common/options" = {lib, ...}: {
    options.features.awww = {
      img = lib.mkOption {
        type = lib.types.path;
        description = "Path to image used for wallpaper";
        default = ../../../assets/media/wallpapers/fog_forest.webp;
      };
      flags = lib.mkOption {
        type = lib.types.str;
        description = "Additional string arguments to add to `awww` command";
        default = "--resize stretch";
      };
    };
  };
  flake.homeModules."feat/tools/awww" = {
    config,
    pkgs,
    ...
  }: let
    img = config.features.awww.img;
    flags = config.features.awww.flags;
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
        ExecStartPost = pkgs.writeShellScript "awww-set-wallpaper" ''
          ${pkg}/bin/awww clear-cache
          for i in $(seq 1 10); do
            if ${pkg}/bin/awww img ${flags} ${img}; then
              exit 0
            fi
            sleep 0.25
          done

          echo "awww-daemon did not become ready" >&2
          exit 1
        '';
        ExecStop = "${pkg}/bin/awww kill";
        Restart = "on-failure";
        RestartSec = "3";
        TimeoutStopSec = "1s";
      };
    };
  };
}
