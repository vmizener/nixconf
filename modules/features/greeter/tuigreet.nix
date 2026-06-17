/*
  feat/greeter/tuigreet

Enables the tuigreet console greeter for greetd.

Exposes:

- flake.nixosModules."feat/greeter/tuigreet":
*/
{
  flake.nixosModules."feat/greeter/tuigreet" = { pkgs, ... }: {
    features.greeter.command = "${pkgs.tuigreet}/bin/tuigreet --time";
  };
}
