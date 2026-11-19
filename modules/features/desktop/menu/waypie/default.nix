/*
  feat/desktop/menu/waypie

Enables the Waypie radial menu tool for Wayland.

Exposes:

- flake.homeModules."feat/desktop/menu/waypie":
- local package: "nix run '.#pkg:waypie'"
*/
{...}: let
  moduleName = "feat/desktop/menu/waypie";
in {
  flake.homeModules.${moduleName} = {
    config,
    pkgs,
    ...
  }: let
    pkg = pkgs.callPackage ./_package.nix {};
  in {
    mod.meta.imported = [moduleName];
    home.packages = [pkg];
    xdg.configFile = {
      "waypie/config".source = config.mod.meta.link ./config.toml;
      "waypie/style.css".source = config.mod.meta.link ./style.css;
      "waypie/icons".source = "${pkg}/share/waypie/icons";
    };
    mod."common/handlers".add.menu.waypie = {
      priority = 100;
      label = "Waypie";
      cmd = ["waypie" "--show"];
    };
  };

  perSystem = {pkgs, ...}: {
    packages."pkg:waypie" = pkgs.callPackage ./_package.nix {};
  };
}
