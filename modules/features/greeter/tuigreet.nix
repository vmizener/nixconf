/*
  feat/greeter/tuigreet

Enables the tuigreet console greeter for greetd.

Exposes:

- flake.nixosModules."feat/greeter/tuigreet":
*/
{ self, ... }: {
  flake.nixosModules."feat/greeter/tuigreet" = { pkgs, ... }: {
    imports = [
      self.nixosModules."feat/greeter"
    ];

    features.greeter.command = "${pkgs.tuigreet}/bin/tuigreet --time";
  };
}
