/*
  feat/shell/zsh

Enables interactive Zsh shell environment with Powerlevel10k theme.

Exposes:

- flake.homeModules."feat/terminal/shell/zsh":
  - Enables Zsh for the user.
*/
{...}: let
  moduleName = "feat/terminal/shell/zsh";
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      extraConfig = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Additional config lines to append to zshrc";
        default = [];
      };
    };
  };
  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};

    hmSessionVars = "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh";
    hmNixProfile = "${config.home.profileDirectory}/etc/profile.d/nix.sh";
  in {
    mod.imported = [moduleName];
    programs.zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      initContent = lib.strings.concatStringsSep "\n" (
        [
          ''[[ -f "${hmSessionVars}" ]] && source "${hmSessionVars}"''
          ''[[ -f "${hmNixProfile}" ]] && source "${hmNixProfile}"''
          "${builtins.readFile ./zshrc}"
          "source ${./p10k.zsh}"
        ]
        ++ (import ./_aliases.nix {
          inherit config pkgs;
          installed = config.home.packages;
        })
        ++ cfg.extraConfig
      );
    };
    home = {
      packages = with pkgs; [
        fzf
      ];
    };
  };
  flake.nixosModules.${moduleName} = {...}: {
    mod.imported = [moduleName];
    programs.zsh.enable = true;
  };
}
