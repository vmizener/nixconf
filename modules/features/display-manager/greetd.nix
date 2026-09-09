/*
  feat/display-manager/greetd

Enables the greetd minimalist display manager.
Greetd separates login service from greeter service.

Exposes:

- flake.nixosModules."feat/display-manager/greetd":
  - Enables greetd login manager
*/
{...}: let
  moduleName = "feat/display-manager/greetd";
in {
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
    options.mod.${moduleName} = {
      greeter = lib.mkOption {
        type = lib.types.enum (lib.attrNames greeters);
        default = "tuigreet";
        description = "Greeter for greetd to use";
      };
      # Derived value (not a user-facing option)
      command = lib.mkOption {
        type = lib.types.str;
        default = greeters.${config.mod.${moduleName}.greeter};
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
  flake.nixosModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    flake.imported = [moduleName];
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
