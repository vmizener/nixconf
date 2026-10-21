{
  config,
  installed,
  lib,
}: let
  installedNames = lib.genAttrs (map lib.getName installed) (_: true);
  addIfElse = want: ifCond: elseCond:
    if installedNames ? ${want}
    then ifCond
    else elseCond;
  addIf = want: ifCond: addIfElse want ifCond [];
in (
  [
    "alias cdf='cd -P ${config.mod.nixconf.path}'"
  ]
  ++ addIf "bat" [
    "alias cat='bat --wrap=never'"
  ]
  ++ addIf "comma" [
    "alias nl='nix-locate'"
    "alias ,,=', -as'"
  ]
  ++ addIfElse "eza" [
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
    "alias lT=\"tree -CpDh | sed -e 's/\\\\(.*\\\\)\\\\[\\\\([^]]*\\\\)\\\\]/\\\\2 \\\\1/'\""
  ]
  ++ addIf "git" [
    "alias cdr='cd $(git rev-parse --show-toplevel)'"
  ]
  ++ addIf "neovim" [
    "alias vi='nvim'"
  ]
  ++ addIf "nh" [
    "alias nf='nh search'"
  ]
  ++ addIf "ov" [
    "export PAGER=ov"
  ]
  ++ addIf "tmux" [
    "alias tl='tmux list-sessions'"
    "alias td='tmux detach'"
    "alias ts='tmux new -s'"
    "alias tt='tmux attach -t'"
    "alias tR='tmux attach'"
  ]
)
