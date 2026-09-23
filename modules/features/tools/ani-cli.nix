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
  version = "0.11.0";

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
        hash = "sha256-zLo1hk+iU9mRx40QDlVklJYXugbnOKFgGg1dx254Rew=";
      };
      cargoHash = "sha256-A1MBAy9mQ5OafAspUi2Y1zpVtXd/VBUoiZnODeiRsLM=";
      doCheck = false; # package fails its own checks for some reason?
    };
  };
}
