/*
  feat/login-manager/greetd

Enables the greetd minimalist login manager.

Exposes:

- flake.nixosModules."feat/login-manager/greetd":
  - Enables greetd login manager
  - Imports `feat/greeter` interface.
*/
{
  flake.nixosModules."feat/login-manager/greetd" = {config, ...}: {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = config.features.greeter.command;
          user = "greeter";
        };
      };
    };
  };
}
