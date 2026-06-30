{
  installed,
  pkgs,
}: let
  addIfElse = want: ifCond: elseCond:
    if builtins.elem want installed
    then ifCond
    else elseCond;
  addIf = want: ifCond: (addIfElse want ifCond []);
in (
  addIf pkgs.bat [
    "alias cat='bat'"
  ]
  ++ addIf pkgs.comma [
    "alias nl='nix-locate'"
    "alias ,,=', -as'"
  ]
  ++ addIfElse pkgs.eza [
    "alias ls='eza --sort=type --icons=always'"
    "alias la='eza --sort=type --icons=always -a'"
    "alias ll='eza --sort=type --icons=always -al --git --header'"
    "alias lt='eza --sort=type --icons=always -T'"
    "alias lT='eza --sort=type --icons=always -lT --git --header'"
  ] [
    "export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx"
    "alias ls='ls -Fh'"
    "alias la='ls -Fha'"
    "alias ll='ls -Fhal'"
    "alias lt='tree'"
    "alias lT=\"tree -CpDh | sed -e 's/\(.*\)\[\([^]]*\)\]/\2 \1/'\""
  ]
  ++ addIf pkgs.git [
    "alias cdr='cd $(git rev-parse --show-toplevel)'"
  ]
  ++ addIf pkgs.neovim [
    "alias vi='nvim'"
  ]
  ++ addIf pkgs.nh [
    "alias nf='nh search'"
  ]
  ++ addIf pkgs.tmux [
    "alias tl='tmux list-sessions'"
    "alias td='tmux detach'"
    "alias ts='tmux new -s'"
    "alias tt='tmux attach -t'"
    "alias tR='tmux attach'"
  ]
)
