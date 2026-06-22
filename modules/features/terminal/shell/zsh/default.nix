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
  flake.homeModules."feat/terminal/shell/zsh" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    hmSessionVars = "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh";
    hmNixProfile = "${config.home.profileDirectory}/etc/profile.d/nix.sh";

    homePkgs = config.home.packages;
  in {
    programs.zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      initContent = lib.strings.concatStringsSep "\n" ([
          ''[[ -f "${hmSessionVars}" ]] && source "${hmSessionVars}"''
          ''[[ -f "${hmNixProfile}" ]] && source "${hmNixProfile}"''
          "${builtins.readFile ./zshrc}"
        ]
        ++ (
          if builtins.elem pkgs.eza homePkgs
          then [
            "alias ls='eza --sort=type --icons=always'"
            "alias la='eza --sort=type --icons=always -a'"
            "alias ll='eza --sort=type --icons=always -al --git --header'"
            "alias lt='eza --sort=type --icons=always -T'"
            "alias lT='eza --sort=type --icons=always -lT --git --header'"
          ]
          else [
            "export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx"
            "alias ls='ls -Fh'"
            "alias la='ls -Fha'"
            "alias ll='ls -Fhal'"
            "alias lt='tree'"
            "alias lT=\"tree -CpDh | sed -e 's/\(.*\)\[\([^]]*\)\]/\2 \1/'\""
          ]
        )
        ++ (
          if builtins.elem pkgs.neovim homePkgs
          then [
            "alias vi='nvim'"
          ]
          else [
          ]
        )
        ++ (
          if builtins.elem pkgs.bat homePkgs
          then [
            "alias cat='bat'"
          ]
          else [
          ]
        )
        ++ (
          if builtins.elem pkgs.git homePkgs
          then [
            "alias cdr='cd $(git rev-parse --show-toplevel)'"
          ]
          else [
          ]
        )
        ++ (
          if builtins.elem pkgs.nh homePkgs
          then [
            "alias nf='nh search'"
          ]
          else [
          ]
        )
        ++ (
          if builtins.elem pkgs.comma homePkgs
          then [
            "alias nl='nix-locate'"
            "alias ,,=', -as'"
          ]
          else [
          ]
        ));
    };
    home = {
      file.".p10k.zsh".source = ./p10k.zsh;
      packages = with pkgs; [
        fzf
      ];
      sessionPath = ["${config.home.profileDirectory}/bin"];
    };
  };

  flake.nixosModules."feat/terminal/shell/zsh" = {};
}
