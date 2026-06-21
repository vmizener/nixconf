/*
  feat/shell/zsh

Enables the interactive Zsh shell environment with Powerlevel10k theme.

Exposes:

- flake.homeModules."feat/terminal/shell/zsh":
  - Enables Zsh for the user.

- flake.nixosModules."feat/terminal/shell/zsh":
  - Enables system-wide Zsh.
*/
{
  flake.homeModules."feat/terminal/shell/zsh" = { config, lib, pkgs, ... }: let
    hmSessionVars = "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh";
    hmNixProfile = "${config.home.profileDirectory}/etc/profile.d/nix.sh";
  in {
    programs.zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      initContent = lib.strings.concatStringsSep "\n" [
        ''[[ -f "${hmSessionVars}" ]] && source "${hmSessionVars}"''
        ''[[ -f "${hmNixProfile}" ]] && source "${hmNixProfile}"''
        "${builtins.readFile ./zshrc}"
      ];
    };
    home = {
      file.".p10k.zsh".source = ./p10k.zsh;
      packages = with pkgs; [
        fzf
      ];
      sessionPath = [ "${config.home.profileDirectory}/bin" ];
    };
  };

  flake.nixosModules."feat/terminal/shell/zsh" = {};
}
