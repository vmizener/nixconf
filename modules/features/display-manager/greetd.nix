/*
  feat/display-manager/greetd

Enables the greetd minimalist display manager.
Greetd separates login service from greeter service.

Exposes:

- flake.nixosModules."feat/display-manager/greetd":
  - Enables greetd login manager
*/
{
  flake.nixosModules."common/options" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    greeters = {
      regreet = "${pkgs.cage}/bin/cage -s -- ${pkgs.greetd.regreet}/bin/regreet";
      tuigreet = "${pkgs.tuigreet}/bin/tuigreet --time";
    };
  in {
    options.features.display-manager.greetd = {
      greeter = lib.mkOption {
        type = lib.types.enum (lib.attrNames greeters);
        default = "tuigreet";
        description = "Greeter for greetd to use";
      };
      # Derived value (not a user-facing option)
      command = lib.mkOption {
        type = lib.types.str;
        default = greeters.${config.features.display-manager.greetd.greeter};
        readOnly = true;
      };

      autologinUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "bao";
        description = ''
          If set, greetd will automatically start an initial session as this user (autologin).
          Set to null to disable.
        '';
      };
    };
  };
  flake.nixosModules."feat/display-manager/greetd" = {
    config,
    lib,
    ...
  }: let
    cfg = config.features.display-manager.greetd;
  in {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = cfg.command;
          user = "greeter";
        };
        initial_session = lib.mkIf (cfg.autologinUser != null) {
          command = cfg.command;
          user = cfg.autologinUser;
        };
      };
    };
  };
}
