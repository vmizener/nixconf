/*
  feat/terminal/emulator/foot

Enables foot terminal emulator.

Exposes:

- flake.homeModules."feat/terminal/emulator/foot":
*/
{...}: let
  moduleName = "feat/terminal/emulator/foot";
in {
  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: {
    mod.meta.imported = [moduleName];
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
      "foot/edit-scrollback.sh" = let
        inherit (config.mod."common/handlers".get) editor;
        editorCmd =
          if editor != null && editor.cmd != null
          then editor.cmd
          else ["vim"];
        isVim = builtins.elem (baseNameOf (builtins.head editorCmd)) ["nvim" "vim"];
        launchCmd =
          if isVim
          then ''
            foot ${lib.escapeShellArgs editorCmd} -u NONE "$f" \
              -c 'set nonumber nolist showtabline=0 foldcolumn=0 virtualedit=block' \
              -c 'autocmd VimEnter * normal G' \
              -c 'map q :qa!<CR>' \
              -c 'map i <NOP>' \
              -c 'map I <NOP>' \
              -c 'map a <NOP>' \
              -c 'map A <NOP>' \
              -c 'set clipboard+=unnamedplus'
          ''
          else ''
            foot ${lib.escapeShellArgs editorCmd} "$f"
          '';
      in {
        executable = true;
        text = ''
          #!/bin/sh

          f=$(mktemp)
          trap 'rm -f "$f"' EXIT

          cat >"$f"

          ${launchCmd}
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
    mod."common/handlers".add.terminal.foot = {
      priority = 100;
      label = "Foot";
      desktop = "foot.desktop";
      cmd = ["foot"];
    };
  };
}
