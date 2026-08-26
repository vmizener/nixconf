/*
  feat/terminal/emulator/foot

Enables foot terminal emulator.

Exposes:

- flake.homeModules."feat/terminal/emulator/foot":
*/
{
  flake.homeModules."feat/terminal/emulator/foot" = {
    config,
    lib,
    pkgs,
    ...
  }: {
    features.terminal.emulators = ["foot"];
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      nerd-fonts.inconsolata
    ];
    xdg.configFile = {
      "foot/fzf-scrollback.sh" = {
        executable = true;
        text = ''
          #!/bin/sh

          f=$(mktemp)
          trap 'rm -f "$f"' EXIT

          cat >"$f"

          foot sh -c 'fzf --no-sort --no-mouse -i --tac < "$1"' sh "$f"
        '';
      };
      "foot/edit-scrollback.sh" = {
        executable = true;
        text = ''
          #!/bin/sh

          f=$(mktemp)
          trap 'rm -f "$f"' EXIT

          cat >"$f"

          editor=${if lib.elem "nvim" config.features.tools then "nvim" else "vim"}

          foot $editor -u NONE "$f" \
            -c 'set nonumber nolist showtabline=0 foldcolumn=0 virtualedit=block' \
            -c 'autocmd VimEnter * normal G' \
            -c 'map q :qa!<CR>' \
            -c 'map i <NOP>' \
            -c 'map I <NOP>' \
            -c 'map a <NOP>' \
            -c 'map A <NOP>' \
            -c 'set clipboard+=unnamedplus'
        '';
      };
    };
    programs.foot = {
      enable = true;
      settings = {
        main = {
          font = "HackNerdFont:size=12";
        };
        colors-dark = {
          alpha = "0.7";
        };
        colors-light = {
          alpha = "0.7";
        };
        key-bindings = {
          font-increase = "Control+Shift+plus Control+Shift+equal Control+KP_Add";
          font-decrease = "Control+Shift+minus Control+KP_Subtract";
          pipe-scrollback = let
            footCfg = "${config.xdg.configHome}/foot";
          in [
            "[sh -c \"${footCfg}/edit-scrollback.sh\"] Control+Shift+f"
            "[sh -c \"${footCfg}/fzf-scrollback.sh\"] Control+Shift+slash"
          ];
          show-urls-launch = "Control+Shift+o";
          show-urls-copy = "Control+Shift+y";
        };
      };
    };
    features.system.mime.categories.terminals = lib.mkIf config.features.system.mime.enable (lib.mkOrder 100 ["foot.desktop"]);
  };
}
