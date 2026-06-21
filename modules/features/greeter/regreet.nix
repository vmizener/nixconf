/*
  feat/greeter/regreet

Enables the ReGreet GTK4 graphical greeter for greetd running under cage.

Exposes:

- flake.nixosModules."feat/greeter/regreet":
*/
{
  flake.nixosModules."feat/greeter/regreet" = {pkgs, ...}: {
    features.greeter.command = "${pkgs.cage}/bin/cage -s -- ${pkgs.greetd.regreet}/bin/regreet";
  };
}
