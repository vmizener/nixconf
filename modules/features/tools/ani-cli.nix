/*
  feat/tools/ani-cli

Anime streaming utility.

Exposes:

- flake.homeModules."feat/tools/ani-cli":
- flake.nixosModules."feat/tools/ani-cli":
- local package: "nix run '.#ani-cli'"
*/
{self, ...}: let
  pkgName = "ani-cli";
  tag = "v4.14";
  hash = "sha256-OyCKDN89sBz59+3JncMDyNOq8UMqqjara+A0Owo3oko=";
in {
  flake.homeModules."feat/tools/ani-cli" = {pkgs, ...}: {
    features.tools = ["ani-cli"];
    home.packages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  flake.nixosModules."feat/tools/ani-cli" = {pkgs, ...}: {
    features.tools = ["ani-cli"];
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  perSystem = {pkgs, ...}: {
    packages.${pkgName} = pkgs.ani-cli.overrideAttrs (_: {
      version = tag;
      src = pkgs.fetchFromGitHub {
        owner = "pystardust";
        repo = pkgName;
        tag = tag;
        hash = hash;
      };
    });
  };
}
