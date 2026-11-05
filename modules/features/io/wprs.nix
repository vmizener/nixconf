/*
  feat/io/wprs

Provides wprs (Wayland remote application streaming) and the `wp` session launcher.

Exposes:

- flake.homeModules."feat/io/wprs":
  - Installs `wprs` (configurable via `package`, or `null` to skip) and the `wp` launcher on `PATH`.
  - Optionally enables the `wprsd` systemd user daemon (`daemon.enable`).
*/
{...}: let
  moduleName = "feat/io/wprs";
in {
  flake.homeModules."common/options" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    options.mod.${moduleName} = {
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = pkgs.wprs;
        defaultText = lib.literalExpression "pkgs.wprs";
        description = "The wprs package to install, or null when managed by the host OS.";
      };
      daemon = {
        enable = lib.mkEnableOption "wprsd systemd user daemon";
        package = lib.mkOption {
          type = lib.types.package;
          default =
            if cfg.package != null
            then cfg.package
            else pkgs.wprs;
          defaultText = lib.literalExpression ''
            if config.mod."feat/io/wprs".package != null
            then config.mod."feat/io/wprs".package
            else pkgs.wprs
          '';
          description = "Package providing wprsd for the systemd user service.";
        };
        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Additional command-line arguments passed to wprsd.";
        };
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
    env = lib.getExe' pkgs.coreutils "env";
    uname = lib.getExe' pkgs.coreutils "uname";
    ss = lib.getExe' pkgs.iproute2 "ss";

    wpLauncher = pkgs.symlinkJoin {
      name = "wp";
      paths = [
        (pkgs.writeShellApplication {
          name = "wp";
          text = ''
            usage() {
              echo "Usage: wp <cmd> [args...]"
            }

            if (( $# == 0 )); then
              usage >&2
              exit 2
            fi

            case "$1" in
              -h | --help)
                usage
                exit 0
                ;;
              --)
                shift
                if (( $# == 0 )); then
                  usage >&2
                  exit 2
                fi
                ;;
            esac

            runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/''${UID}}"
            if [[ ! -S "''${runtime_dir}/wprs-0" ]]; then
              echo "wp: wprsd is not running (''${runtime_dir}/wprs-0 not found)" >&2
              exit 1
            fi
            if [[ -z "$("${ss}" -H -x state connected src "''${runtime_dir}/wprs.sock" 2>/dev/null)" ]]; then
              host="''${HOSTNAME:-$("${uname}" -n)}"
              echo "wp: no attached wprs session (run 'wprs ''${host} attach' on client)" >&2
              exit 1
            fi

            wprs_env=(
              WAYLAND_DISPLAY=wprs-0
              DISPLAY=:100
              XDG_SESSION_TYPE=wayland
              SDL_VIDEODRIVER=wayland
              PULSE_SERVER="unix:''${runtime_dir}/wprs-pulse"
            )

            exec "${env}" "''${wprs_env[@]}" "$@"
          '';
        })
        # zsh autocomplete support
        (pkgs.writeTextDir "share/zsh/site-functions/_wp" ''
          #compdef wp
          _precommand
        '')
      ];
      meta.mainProgram = "wp";
    };
  in {
    mod.meta.imported = [moduleName];

    home.packages =
      [wpLauncher]
      ++ lib.optional (cfg.package != null) cfg.package;

    systemd.user.services.wprsd = lib.mkIf cfg.daemon.enable {
      Unit = {
        Description = "wprsd Wayland remote display daemon";
        After = ["network.target"];
      };
      Service = {
        Type = "simple";
        ExecStart =
          (["${cfg.daemon.package}/bin/wprsd"] ++ map lib.escapeShellArg cfg.daemon.extraArgs)
          |> lib.concatStringsSep " ";
        Environment = [
          "RUST_BACKTRACE=1"
          "PATH=${lib.makeBinPath [cfg.daemon.package pkgs.xwayland]}:/run/current-system/sw/bin:/usr/bin:/bin"
        ];
        Restart = "on-failure";
        RestartSec = "3";
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };
  };
}
