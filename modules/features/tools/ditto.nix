/*
  feat/tools/ditto

Keyboard visualizer utility.

Exposes:

- flake.homeModules."feat/tools/ditto":
- flake.nixosModules."feat/tools/ditto":
- local package: "nix run '.#float'"
*/
let
  moduleName = "feat/tools/ditto";

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
    mod.imported = [moduleName];
    home.packages = [(pkgs.callPackage mkPkg {})];
  };
  flake.nixosModules.${moduleName} = {pkgs, ...}: {
    mod.imported = [moduleName];
    environment.systemPackages = [(pkgs.callPackage mkPkg {})];
  };
  perSystem = {pkgs, ...}: {
    packages."pkg:${pkgName}" = pkgs.callPackage mkPkg {};
  };
}
