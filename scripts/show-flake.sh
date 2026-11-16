#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

nix eval --impure --json --expr "
  let
    flake = builtins.getFlake \"git+file://${repo_root}\";
    unique = list: builtins.attrNames (builtins.groupBy (x: x) list);
  in {
    homeModules = builtins.attrNames (flake.homeModules or {});
    homeConfigurations = builtins.attrNames (flake.homeConfigurations or {});
    nixosModules = builtins.attrNames (flake.nixosModules or {});
    nixosConfigurations = builtins.attrNames (flake.nixosConfigurations or {});
    packages = unique (
      builtins.concatLists (
        builtins.attrValues (
          builtins.mapAttrs (_: p: builtins.attrNames p) (flake.packages or {})
        )
      )
    );
  }
"
