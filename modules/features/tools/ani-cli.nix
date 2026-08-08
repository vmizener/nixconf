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
  version = "5.0";
  hash = "sha256-rRQESi0Skoyf1jy/dRRK6ooKRPQhkak107kk5ulwZYI=";
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
      version = version;
      src = pkgs.fetchFromGitHub {
        owner = "pystardust";
        repo = pkgName;
        tag = "v${version}";
        hash = hash;
      };
    });
  };
}
