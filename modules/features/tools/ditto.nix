/*
  feat/tools/ditto

Keyboard visualizer utility.

Exposes:

- flake.homeModules."feat/tools/ditto":
- flake.nixosModules."feat/tools/ditto":
- local package: "nix run '.#float'"
*/
{self, ...}: let
  pkgName = "ditto";
  version = "1.3.3";
  pkgHash = "sha256-pn8uFVSR409dEGDSqJXJZ3h7NzdClew57YMPankCtw8=";
  vendorHash = "sha256-+DDBmGSsllHJ7D4/koKWq1MEVuUJJRebn3J8mxEQ8p8=";
in {
  flake.homeModules."feat/tools/ditto" = {pkgs, ...}: {
    features.tools = ["ditto"];
    home.packages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  flake.nixosModules."feat/tools/ditto" = {pkgs, ...}: {
    features.tools = ["ditto"];
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  perSystem = {pkgs, ...}: {
    packages."pkg:${pkgName}" = pkgs.buildGoModule {
      pname = pkgName;
      version = version;
      src = pkgs.fetchFromGitHub {
        owner = "arvingarciabtw";
        repo = pkgName;
        tag = "v${version}";
        hash = pkgHash;
      };
      vendorHash = vendorHash;
    };
  };
}
