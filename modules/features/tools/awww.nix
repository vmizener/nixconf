/*
  feat/tools/awww

Enables AWWW wallpaper service.

Exposes:

- flake.homeModules."feat/tools/awww":
*/
{inputs, ...}: let
  moduleName = "feat/tools/awww";
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.features.tools.awww = {
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
  flake.homeModules.${moduleName} = {
    config,
    pkgs,
    ...
  }: let
    img = config.features.tools.awww.img;
    flags = config.features.tools.awww.flags;
    pkg = inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww;
  in {
    flake.imported = [moduleName];
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
