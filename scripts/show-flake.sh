#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

nix eval --json "git+file://${repo_root}#debug.flake" "$@" --apply '
  flake: let
    unique = list: builtins.attrNames (builtins.groupBy (x: x) list);
    perSystemNames = attr:
      unique (
        builtins.concatLists (
          builtins.attrValues (
            builtins.mapAttrs (_: builtins.attrNames) (
              if builtins.hasAttr attr flake
              then builtins.getAttr attr flake
              else {}
            )
          )
        )
      );
  in {
    apps = perSystemNames "apps";
    homeModules = builtins.attrNames (flake.homeModules or {});
    homeConfigurations = builtins.attrNames (flake.homeConfigurations or {});
    nixosModules = builtins.attrNames (flake.nixosModules or {});
    nixosConfigurations = builtins.attrNames (flake.nixosConfigurations or {});
    packages = perSystemNames "packages";
  }
'
