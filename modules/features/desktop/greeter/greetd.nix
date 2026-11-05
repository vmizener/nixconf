/*
  feat/desktop/greeter/greetd

Enables the greetd minimalist display manager.
Greetd separates login service from greeter service.

Exposes:

- flake.nixosModules."feat/desktop/greeter/greetd":
  - Enables greetd login manager with Wayland and X11 session discovery
*/
{...}: let
  moduleName = "feat/desktop/greeter/greetd";
in {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      greeter = lib.mkOption {
        type = lib.types.enum ["regreet" "tuigreet"];
        default = "tuigreet";
        description = "Greeter for greetd to use";
      };
      autologinUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "bao";
        description = ''
          If set, greetd will automatically start an initial session as this user (autologin).
          Requires `autologinCommand` to also be set. Set to null to disable.
        '';
      };
      autologinCommand = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "niri-session";
        description = ''
          Session command executed by greetd's `initial_session` when `autologinUser` is set.
        '';
      };
    };
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    hasX11 = config.services.xserver.enable;
    x11Wrapper = [
      "${pkgs.xinit}/bin/startx"
      "${config.services.displayManager.sessionData.wrapper}"
    ];
  in
    lib.mkMerge [
      # Base config
      {
        mod.meta.imported = [moduleName];

        assertions = [
          {
            assertion = (cfg.autologinUser != null) -> (cfg.autologinCommand != null);
            message = ''mod."${moduleName}".autologinUser requires mod."${moduleName}".autologinCommand to be set.'';
          }
        ];

        services.xserver.displayManager.startx.enable = lib.mkIf hasX11 (lib.mkDefault true);

        services.greetd = {
          enable = true;
          settings = lib.optionalAttrs (cfg.autologinUser != null) {
            initial_session = {
              command = cfg.autologinCommand;
              user = cfg.autologinUser;
            };
          };
        };
      }

      # `tuigreet` config
      (lib.mkIf (cfg.greeter == "tuigreet") {
        services.greetd = {
          useTextGreeter = true;
          settings.default_session = {
            user = "greeter";
            command = let
              sessions = "${config.services.displayManager.sessionData.desktops}/share";
            in
              [
                (lib.getExe pkgs.tuigreet)
                "--time"
                "--asterisks"
                "--sessions"
                "${sessions}/wayland-sessions"
                "--xsessions"
                "${sessions}/xsessions"
              ]
              ++ lib.optionals hasX11 [
                "--xsession-wrapper"
                (lib.concatStringsSep " " x11Wrapper)
              ]
              |> lib.escapeShellArgs;
          };
        };
      })

      # `regreet` config
      (lib.mkIf (cfg.greeter == "regreet") {
        services.displayManager.regreet = {
          enable = true;
          settings = lib.optionalAttrs hasX11 {
            commands.x11_prefix = x11Wrapper;
          };
        };
      })
    ];
}
