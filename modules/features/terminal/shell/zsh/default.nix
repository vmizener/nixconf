/*
  feat/shell/zsh

Enables interactive Zsh shell environment with Powerlevel10k theme.

Exposes:

- flake.homeModules."feat/terminal/shell/zsh":
  - Enables Zsh for the user.
*/
{
  flake.homeModules."feat/terminal/shell/zsh" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    hmSessionVars = "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh";
    hmNixProfile = "${config.home.profileDirectory}/etc/profile.d/nix.sh";
  in {
    programs.zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      initContent = lib.strings.concatStringsSep "\n" ([
          ''[[ -f "${hmSessionVars}" ]] && source "${hmSessionVars}"''
          ''[[ -f "${hmNixProfile}" ]] && source "${hmNixProfile}"''
          "${builtins.readFile ./zshrc}"
          "alias cdf='cd ${config.flakePath}'"
        ]
        ++ (import ./_aliases.nix {
          inherit pkgs;
          installed = config.home.packages;
        }));
    };
    home = {
      packages = with pkgs; [
        fzf
      ];
      file.".p10k.zsh".source = ./p10k.zsh;
    };
  };
}
