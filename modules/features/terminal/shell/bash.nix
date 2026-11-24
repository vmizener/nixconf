/*
  feat/terminal/shell/bash

Enables a bare-bones interactive Bash shell environment.

Exposes:

- flake.homeModules."common/options" (options.mod."feat/terminal/shell/bash")
- flake.homeModules."feat/terminal/shell/bash":
  - Enables interactive Bash with completion, XDG history, and `common/handlers`
    shell registration.
- flake.nixosModules."feat/terminal/shell/bash":
  - Enables system-wide interactive Bash with programmable completion and `LS_COLORS`.
*/
{...}: let
  moduleName = "feat/terminal/shell/bash";
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      extraConfig = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional config lines to append to bashrc.";
      };
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
    hmNixProfile = "${config.home.profileDirectory}/etc/profile.d/nix.sh";
    hmSessionVars = "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh";
  in {
    mod = {
      meta = {
        imported = [moduleName];
        asserts = ["pairedNixosFeat"];
      };
      "common/handlers".add.shell.bash = {
        priority = 200;
        label = "Bash";
        cmd = ["${config.home.profileDirectory}/bin/bash"];
      };
    };
    programs.bash = {
      enable = true;
      enableCompletion = true;
      historyControl = [
        "erasedups"
        "ignoredups"
        "ignorespace"
      ];
      historyFile = "${config.xdg.stateHome}/bash/history";
      historyFileSize = 50000;
      historySize = 5000;
      bashrcExtra = ''
        [[ -f "${hmNixProfile}" ]] && source "${hmNixProfile}"
      '';
      initExtra = lib.concatStringsSep "\n" (
        [
          ''[[ -f "${hmSessionVars}" ]] && source "${hmSessionVars}"''
        ]
        ++ cfg.extraConfig
      );
    };
  };

  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
    programs.bash = {
      enable = true;
      completion.enable = true;
      enableLsColors = true;
    };
  };
}
