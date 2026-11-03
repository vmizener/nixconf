/*
  feat/terminal/mux/tmux

Enables tmux multiplexer.

Exposes:

- flake.homeModules."feat/terminal/mux/tmux":
*/
let
  moduleName = "feat/terminal/mux/tmux";
in {
  flake.homeModules.${moduleName} = {
    config,
    pkgs,
    ...
  }: {
    mod.meta.imported = [moduleName];
    programs.tmux = {
      enable = true;

      historyLimit = 10000;
      keyMode = "vi";
      mouse = true;
      terminal = "tmux-256color";

      plugins = with pkgs; [
        {
          plugin = tmuxPlugins.resurrect;
          extraConfig = "set -g @resurrect-strategy-nvim 'session'";
        }
      ];
      extraConfig = builtins.readFile ./tmux.conf;
    };
  };
}
