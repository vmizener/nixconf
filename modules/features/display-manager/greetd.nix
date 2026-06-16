/*
  feat/display-manager/greetd

Enables the greetd minimalist login manager with tuigreet.

Exposes:

- flake.nixosModules."feat/display-manager/greetd":
  - Enables greetd login manager
  - Configures tuigreet TUI greeter session.
*/
{
  flake.nixosModules."feat/display-manager/greetd" = { pkgs, ... }: {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time";
          user = "greeter";
        };
      };
    };
  };
}
