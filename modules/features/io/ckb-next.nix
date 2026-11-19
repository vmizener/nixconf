/*
  feat/io/ckb-next

Enables the CKB-Next open-source driver for Corsair keyboards and mice.

Exposes:

- flake.nixosModules."feat/io/ckb-next":
- local package: "nix run '.#pkg:ckb-next'"
*/
{...}: let
  moduleName = "feat/io/ckb-next";

  pkgName = "ckb-next";
  # Track master for Scimitar RGB Elite support (unreleased after v0.6.2)
  version = "0.6.2-unstable-2026-10-21";
  rev = "e22eaf2fba7f93764b4c6d4413bb83eeca75d10a";

  mkPkg = {
    ckb-next,
    fetchFromGitHub,
  }:
    ckb-next.overrideAttrs (old: {
      inherit version;
      src = fetchFromGitHub {
        owner = "ckb-next";
        repo = pkgName;
        inherit rev;
        hash = "sha256-v/qazMy25SETYJcYMGW91ZuLL1YoPdCwwkPn899TDyM=";
      };
      passthru =
        (old.passthru or {})
        // {
          nixUpdateArgs = ["--version=branch"];
        };
    });
in {
  flake.nixosModules.${moduleName} = {
    lib,
    pkgs,
    ...
  }: let
    pkg = pkgs.callPackage mkPkg {};
  in {
    mod.meta.imported = [moduleName];
    hardware.ckb-next = {
      enable = true;
      package = pkg;
    };
    systemd.user.services.ckb-next = {
      enable = true;
      description = "Corsair keyboard next service";
      after = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe pkg} -b";
        Restart = "on-failure";
        RestartSec = "3";
      };
    };
  };

  perSystem = {pkgs, ...}: {
    packages."pkg:${pkgName}" = pkgs.callPackage mkPkg {};
  };
}
