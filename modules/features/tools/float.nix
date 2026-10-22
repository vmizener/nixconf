/*
  feat/tools/float

Floating terminal utility.

Exposes:

- flake.homeModules."feat/tools/float":
- flake.nixosModules."feat/tools/float":
- local package: "nix run '.#float'"
*/
let
  moduleName = "feat/tools/float";

  pkgName = "float";
  version = "1.2.1";

  mkPkg = {
    fetchFromGitHub,
    rustPlatform,
  }:
    rustPlatform.buildRustPackage {
      pname = pkgName;
      version = version;
      src = fetchFromGitHub {
        owner = "henktorius";
        repo = pkgName;
        tag = "v${version}";
        hash = "sha256-ngklCMJ54ZFPaWB3c79mzcRKGSiB9sw4KcAKWcVPgao=";
      };
      cargoHash = "sha256-/xlH29DM/psGOME0w2a1v5kG7uxlKsMlP4r+5NENA6M=";
      meta.mainProgram = "float-mux";
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
