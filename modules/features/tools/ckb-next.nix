/*
  feat/tools/ckb-next

Enables the CKB-Next open-source driver for Corsair keyboards and mice.

Exposes:

- flake.nixosModules."feat/tools/ckb-next":
- local package: "nix run '.#pkg:ckb-next'"
*/
{self, ...}: let
  moduleName = "feat/tools/ckb-next";

  pkgName = "ckb-next";
  # 06/02/2026 revision (supports Scimitar RGB Elite)
  rev = "5edd3c14810c1aa93be5adde471071b97ef108b4";

  localPkg = pkgs: self.packages.${pkgs.stdenv.hostPlatform.system}."pkg:${pkgName}";
in {
  flake.nixosModules.${moduleName} = {
    lib,
    pkgs,
    ...
  }: let
    pkg = localPkg pkgs;
  in {
    mod.imported = [moduleName];
    environment.systemPackages = [pkg];
    hardware.ckb-next = {
      enable = true;
      package = pkg;
    };
    systemd.user.services.ckb-next = {
      enable = true;
      description = "Corsair keyboard next service";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe pkg} -b";
        Restart = "on-failure";
        RestartSec = "3";
      };
      wantedBy = ["default.target"];
    };
  };

  perSystem = {pkgs, ...}: {
    packages."pkg:${pkgName}" = pkgs.ckb-next.overrideAttrs (_: {
      src = pkgs.fetchFromGitHub {
        owner = "ckb-next";
        repo = pkgName;
        inherit rev;
        hash = "sha256-h5jZqiK4hYqlLFPY9jmJEniarSHE4ZcoIX4Qv3QdELc=";
      };
    });
  };
}
