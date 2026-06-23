/*
  feat/tools/tmux

Enables tmux multiplexer.

Exposes:

- flake.homeModules."feat/tools/tmux":
*/
{
  flake.homeModules."feat/tools/tmux" = {
    config,
    pkgs,
    ...
  }: {
    features.tools = ["tmux"];
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
