/*
  feat/media/playback/ani-cli

Anime streaming utility.

Exposes:

- flake.homeModules."feat/media/playback/ani-cli":
- flake.nixosModules."feat/media/playback/ani-cli":
- local package: "nix run '.#ani-cli-rs'"
*/
{...}: let
  moduleName = "feat/media/playback/ani-cli";

  pkgName = "ani-cli-rs";
  version = "0.11.3";

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
        hash = "sha256-qbfOrYzMo4Ow2v+QeZMjSvN6iaVgpIoSFb0rZlNygZM=";
      };
      cargoHash = "sha256-ql/ohwsxOOFfbiQ4hLvbrTU8X9qIsc+Ju9l7DYOJiHU=";
      doCheck = false; # package fails its own checks for some reason?
    };
in {
  flake.homeModules.${moduleName} = {
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: {
    mod.meta.imported = [moduleName];
    home.packages = lib.mkIf (osConfig == null || !(osConfig.mod.meta.has moduleName)) [
      (pkgs.callPackage mkPkg {})
    ];
  };
  flake.nixosModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
    environment.systemPackages = [(pkgs.callPackage mkPkg {})];
  };
  perSystem = {pkgs, ...}: {
    packages."pkg:${pkgName}" = pkgs.callPackage mkPkg {};
  };
}
