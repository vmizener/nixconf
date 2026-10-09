/*
  feat/terminal/shell/bash

Enables the interactive Bash shell environment.

Exposes:

- flake.homeModules."feat/terminal/shell/bash":
  - Enables Bash for the user.
- flake.nixosModules."feat/terminal/shell/bash":
*/
{...}: let
  moduleName = "feat/terminal/shell/bash";
in {
  flake.homeModules.${moduleName} = {...}: {
    mod.imported = [moduleName];
    programs.bash.enable = true;
  };
  flake.nixosModules.${moduleName} = {...}: {
    mod.imported = [moduleName];
  };
}
