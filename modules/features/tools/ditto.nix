/*
  feat/tools/ditto

Keyboard visualizer utility.

Exposes:

- flake.homeModules."feat/tools/ditto":
- flake.nixosModules."feat/tools/ditto":
- local package: "nix run '.#float'"
*/
{self, ...}: let
  pkgName = "ditto";
  tag = "v1.0.3";
  pkgHash = "sha256-i0WBLonmTLuvEtCjySca2Vx2ZvdyUZcb0uBpj9bRXIU=";
  vendorHash = "sha256-vk+ahWFGowJt19qk+iCpInKIq0GFIT34HqbSQVSPJrY=";
in {
  flake.homeModules."feat/tools/ditto" = {pkgs, ...}: {
    features.tools = ["ditto"];
    home.packages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  flake.nixosModules."feat/tools/ditto" = {pkgs, ...}: {
    features.tools = ["ditto"];
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.${pkgName}];
  };
  perSystem = {pkgs, ...}: {
    packages.${pkgName} = pkgs.buildGoModule {
      pname = pkgName;
      version = tag;
      src = pkgs.fetchFromGitHub {
        owner = "arvingarciabtw";
        repo = pkgName;
        tag = tag;
        hash = pkgHash;
      };
      vendorHash = vendorHash;
    };
  };
}
