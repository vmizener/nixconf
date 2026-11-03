/*
  feat/io/ditto

Keyboard visualizer utility.

Exposes:

- flake.homeModules."feat/io/ditto":
- flake.nixosModules."feat/io/ditto":
- local package: "nix run '.#float'"
*/
let
  moduleName = "feat/io/ditto";

  pkgName = "ditto";
  version = "1.3.3";

  mkPkg = {
    buildGoModule,
    fetchFromGitHub,
  }:
    buildGoModule {
      pname = pkgName;
      version = version;
      src = fetchFromGitHub {
        owner = "arvingarciabtw";
        repo = pkgName;
        tag = "v${version}";
        hash = "sha256-pn8uFVSR409dEGDSqJXJZ3h7NzdClew57YMPankCtw8=";
      };
      vendorHash = "sha256-+DDBmGSsllHJ7D4/koKWq1MEVuUJJRebn3J8mxEQ8p8=";
    };
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    home.packages = [(pkgs.callPackage mkPkg {})];
  };
  flake.nixosModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    environment.systemPackages = [(pkgs.callPackage mkPkg {})];
  };
  perSystem = {pkgs, ...}: {
    packages."pkg:${pkgName}" = pkgs.callPackage mkPkg {};
  };
}
