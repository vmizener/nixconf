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

    wpScript = pkgs.replaceVars ./wp.sh {
      ENV_BIN = lib.getExe' pkgs.coreutils "env";
      SS_BIN = lib.getExe' pkgs.iproute2 "ss";
      UNAME_BIN = lib.getExe' pkgs.coreutils "uname";
    };

    wpLauncher =
      pkgs.runCommand "wp" {
        nativeBuildInputs = [pkgs.shellcheck];
        meta.mainProgram = "wp";
      } ''
        install -Dm755 "${wpScript}" "$out/bin/wp"
        install -Dm644 "${./_wp}" "$out/share/zsh/site-functions/_wp"
        patchShebangs "$out/bin/wp"
        shellcheck -s bash "$out/bin/wp"
      '';
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
