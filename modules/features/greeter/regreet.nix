/*
  feat/greeter/regreet

Enables the ReGreet GTK4 graphical greeter for greetd running under cage.

Exposes:

- flake.nixosModules."feat/greeter/regreet":
*/
{ self, ... }: {
  flake.nixosModules."feat/greeter/regreet" = { pkgs, ... }: {
    imports = [
      self.nixosModules."feat/greeter"
    ];

    features.greeter.command = "${pkgs.cage}/bin/cage -s -- ${pkgs.greetd.regreet}/bin/regreet";
  };
}
