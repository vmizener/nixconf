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
  }: let
    footBin = lib.getExe config.programs.foot.package;
  in {
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
      "foot/fzf-scrollback.sh".source = pkgs.replaceVarsWith {
        src = ./fzf-scrollback.sh;
        isExecutable = true;
        replacements = {
          FOOT_BIN = footBin;
        };
      };
      "foot/edit-scrollback.sh".source = let
        inherit (config.mod."common/handlers".get) editor;
        editorCmd =
          if editor != null && editor.cmd != null
          then editor.cmd
          else ["vim"];
      in
        pkgs.replaceVarsWith {
          src = ./edit-scrollback.sh;
          isExecutable = true;
          replacements = {
            FOOT_BIN = footBin;
            EDITOR_CMD_FILE = pkgs.writeText "foot-editor-cmd" (lib.concatLines editorCmd);
          };
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
