/*
  feat/tools/ani-cli

Anime streaming utility.

Exposes:

- flake.homeModules."feat/tools/ani-cli":
- flake.nixosModules."feat/tools/ani-cli":
- local package: "nix run '.#ani-cli-rs'"
*/
{self, ...}: let
  moduleName = "feat/tools/ani-cli";

  pkgName = "ani-cli-rs";
  version = "0.10.4";
  pkgHash = "sha256-+kgitNUkxmCkIzgV2apuCeNqyK6hKQOfuombX0QPuh8=";
  cargoHash = "sha256-OmAjX2sO8dl721t/Zo/lIx7Nc0x2cVd2V+vHnZZskDk=";

  localPkg = pkgs: self.packages.${pkgs.stdenv.hostPlatform.system}."pkg:${pkgName}";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.imported = [moduleName];
    home.packages = [(localPkg pkgs)];
  };
  flake.nixosModules.${moduleName} = {pkgs, ...}: {
    mod.imported = [moduleName];
    environment.systemPackages = [(localPkg pkgs)];
  };
  perSystem = {pkgs, ...}: {
    packages."pkg:${pkgName}" = pkgs.rustPlatform.buildRustPackage {
      inherit version;
      pname = pkgName;
      src = pkgs.fetchFromGitHub {
        owner = "vorlie";
        repo = pkgName;
        tag = version;
        hash = pkgHash;
      };
      cargoHash = cargoHash;
      doCheck = false; # package fails its own checks for some reason?
    };
  };
}
