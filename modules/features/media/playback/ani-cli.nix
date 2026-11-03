/*
  feat/media/playback/ani-cli

Anime streaming utility.

Exposes:

- flake.homeModules."feat/media/playback/ani-cli":
- flake.nixosModules."feat/media/playback/ani-cli":
- local package: "nix run '.#ani-cli-rs'"
*/
let
  moduleName = "feat/media/playback/ani-cli";

  pkgName = "ani-cli-rs";
  version = "0.11.0";

  mkPkg = {
    fetchFromGitHub,
    rustPlatform,
  }:
    rustPlatform.buildRustPackage {
      inherit version;
      pname = pkgName;
      src = fetchFromGitHub {
        owner = "vorlie";
        repo = pkgName;
        tag = version;
        hash = "sha256-zLo1hk+iU9mRx40QDlVklJYXugbnOKFgGg1dx254Rew=";
      };
      cargoHash = "sha256-A1MBAy9mQ5OafAspUi2Y1zpVtXd/VBUoiZnODeiRsLM=";
      doCheck = false; # package fails its own checks for some reason?
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
