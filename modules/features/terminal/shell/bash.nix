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
  flake.homeModules.${moduleName} = {config, ...}: {
    mod = {
      meta.imported = [moduleName];
      "common/handlers".add.shell.bash = {
        priority = 200;
        label = "Bash";
        cmd = ["${config.home.profileDirectory}/bin/bash"];
      };
    };
    programs.bash.enable = true;
  };
  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
  };
}
