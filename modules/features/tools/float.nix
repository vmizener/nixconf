/*
  feat/tools/float

Floating terminal utility.

Exposes:

- flake.homeModules."feat/tools/float":
- flake.nixosModules."feat/tools/float":
- local package: "nix run '.#float'"
*/
{self, ...}: let
  pkgName = "float";
  version = "1.2.1";
  pkgHash = "sha256-ngklCMJ54ZFPaWB3c79mzcRKGSiB9sw4KcAKWcVPgao=";
  cargoHash = "sha256-/xlH29DM/psGOME0w2a1v5kG7uxlKsMlP4r+5NENA6M=";
in {
  flake.homeModules."feat/tools/float" = {pkgs, ...}: {
    features.tools = ["float"];
    home.packages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  flake.nixosModules."feat/tools/float" = {pkgs, ...}: {
    features.tools = ["float"];
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  perSystem = {pkgs, ...}: {
    packages.${pkgName} = pkgs.rustPlatform.buildRustPackage {
      pname = pkgName;
      version = version;
      src = pkgs.fetchFromGitHub {
        owner = "henktorius";
        repo = pkgName;
        tag = "v${version}";
        hash = pkgHash;
      };
      cargoHash = cargoHash;
      meta.mainProgram = "float-mux";
    };
  };
}
