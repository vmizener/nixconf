/*
  feat/greeter

Provides greeter interface options and verification for greetd login sessions.

Exposes:

- flake.nixosModules."feat/greeter":
  - Declares `features.greeter.command` option (defaults to tuigreet)
  - Asserts that `services.greetd.enable` is true when imported.
*/
{
  flake.nixosModules."feat/greeter" = { config, lib, pkgs, ... }: {
    options.features.greeter = {
      command = lib.mkOption {
        type = lib.types.str;
        default = "${pkgs.tuigreet}/bin/tuigreet --time";
        description = "Command to run for the greetd default session";
      };
    };

    config = {
      assertions = [
        {
          assertion = config.services.greetd.enable;
          message = "Any feat/greeter module requires a login manager (such as feat/login-manager/greetd) to be enabled.";
        }
      ];
    };
  };
}
