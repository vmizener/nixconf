/*
  feat/tools/ani-cli

Anime streaming utility.

Exposes:

- flake.homeModules."feat/tools/ani-cli":
- flake.nixosModules."feat/tools/ani-cli":
- local package: "nix run '.#ani-cli'"
*/
{self, ...}: let
  moduleName = "feat/tools/ani-cli";

  pkgName = "ani-cli";
  version = "5.0";
  hash = "sha256-rRQESi0Skoyf1jy/dRRK6ooKRPQhkak107kk5ulwZYI=";

  localPkg = pkgs: self.packages.${pkgs.stdenv.hostPlatform.system}."pkg:${pkgName}";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    flake.imported = [moduleName];
    home.packages = [(localPkg pkgs)];
  };
  flake.nixosModules.${moduleName} = {pkgs, ...}: {
    flake.imported = [moduleName];
    environment.systemPackages = [(localPkg pkgs)];
  };
  perSystem = {pkgs, ...}: {
    packages."pkg:${pkgName}" = pkgs.ani-cli.overrideAttrs (_: {
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
