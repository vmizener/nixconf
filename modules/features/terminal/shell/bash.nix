/*
  feat/terminal/shell/bash

Enables the interactive Bash shell environment.

Exposes:

- flake.nixosModules."feat/terminal/shell/bash":
*/
{...}: let
  moduleName = "feat/terminal/shell/bash";
in {
  flake.nixosModules.${moduleName} = {...}: {
    mod.imported = [moduleName];
  };
}
