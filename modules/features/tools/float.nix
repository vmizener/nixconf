/*
  feat/tools/float

Floating terminal utility.

Exposes:

- flake.homeModules."feat/tools/float":
- local package: "nix run '.#float'"
*/
{self, ...}: let
  pkgName = "float";
  pkgVersion = "v1.2.1";
  pkgHash = "f39b21a0f167afce17f07117a589daad9fb89364";
in {
  flake.homeModules."feat/tools/float" = {pkgs, ...}: {
    features.tools = ["float"];
    home.packages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  flake.nixosModules."feat/tools/float" = {pkgs, ...}: {
    features.tools = ["float"];
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  perSystem = {
    pkgs,
    config,
    ...
  }: {
    packages.${pkgName} = pkgs.rustPlatform.buildRustPackage {
      pname = "${pkgName}";
      version = pkgVersion;
      src = pkgs.fetchFromGitHub {
        owner = "henktorius";
        repo = "float";
        rev = pkgHash;
        hash = "sha256-ngklCMJ54ZFPaWB3c79mzcRKGSiB9sw4KcAKWcVPgao=";
      };
      cargoHash = "sha256-/xlH29DM/psGOME0w2a1v5kG7uxlKsMlP4r+5NENA6M=";
      meta.mainProgram = "float-mux";
    };
    apps.${pkgName} = {
      type = "app";
      program = "${config.packages.${pkgName}}/bin/float-mux";
    };
  };
}
