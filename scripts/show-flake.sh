#!/usr/bin/env bash

nix eval --impure --json --expr '
  let
    flake = builtins.getFlake ("git+file://" + (builtins.getEnv "PWD"));
    unique = list: builtins.attrNames (builtins.groupBy (x: x) list);
  in {
    homeModules = builtins.attrNames (flake.homeModules or {});
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
'
