{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mod."feat/desktop/manager/xfce";
  inherit (config.mod."common/handlers".get) browser fileManager terminal;
  inherit (config.mod.meta) isVm;
  termCmd =
    if terminal != null && terminal.cmd != null
    then lib.escapeShellArgs terminal.cmd
    else null;
in
  lib.mkMerge [
    {xfconf.enable = true;}

    (let
      helpers =
        lib.optionalAttrs (terminal != null) {
          TerminalEmulator = {
            inherit (terminal) label;
            cmd =
              if termCmd != null
              then termCmd
              else "xdg-terminal-exec";
            cmdWithParam = "xdg-terminal-exec -- %s";
            icon = "utilities-terminal";
          };
        }
        // lib.optionalAttrs (browser != null) (let
          cmd =
            if browser.cmd != null
            then lib.escapeShellArgs browser.cmd
            else "handlr launch x-scheme-handler/http";
        in {
          WebBrowser = {
            inherit (browser) label;
            inherit cmd;
            cmdWithParam =
              if browser.cmd != null
              then ''${cmd} "%s"''
              else ''${cmd} -- "%s"'';
            icon = "web-browser";
          };
        })
        // lib.optionalAttrs (fileManager != null) (let
          cmd =
            if fileManager.cmd != null
            then lib.escapeShellArgs fileManager.cmd
            else "handlr launch inode/directory";
        in {
          FileManager = {
            inherit (fileManager) label;
            inherit cmd;
            cmdWithParam =
              if fileManager.cmd != null
              then ''${cmd} "%s"''
              else ''${cmd} -- "%s"'';
            icon = "system-file-manager";
          };
        });
    in
      lib.mkIf (helpers != {}) {
        xdg.configFile."xfce4/helpers.rc".text =
          helpers
          |> lib.mapAttrsToList (cat: _: "${cat}=custom-${cat}")
          |> lib.concatLines;
        xdg.dataFile = lib.mapAttrs' (cat: h:
          lib.nameValuePair "xfce4/helpers/custom-${cat}.desktop" {
            source = pkgs.replaceVars ./helper.desktop {
              CATEGORY = cat;
              COMMANDS = h.cmd;
              COMMANDS_WITH_PARAMETER = h.cmdWithParam;
              ICON = h.icon;
              NAME = h.label;
            };
          })
        helpers;
      })

    (lib.mkIf (termCmd != null) {
      xfconf.settings.xfce4-keyboard-shortcuts = {
        "commands/custom/override" = true;
        "commands/custom/<${
          if isVm
          then "Alt"
          else "Super"
        }>Return" =
          termCmd;
      };
    })

    (lib.mkIf (cfg.wallpaper != null) (let
      relPath = "wallpapers/${baseNameOf (toString cfg.wallpaper)}";
      wallpaper = "${config.xdg.dataHome}/${relPath}";
    in {
      xdg.dataFile.${relPath}.source = cfg.wallpaper;
      xfconf.settings.xfce4-desktop =
        {
          "backdrop/screen0/monitor0/image-path" = wallpaper;
          "backdrop/screen0/monitor0/image-show" = true;
          "backdrop/screen0/monitor0/workspace0/image-style" = 5;
          "backdrop/screen0/monitor0/workspace0/last-image" = wallpaper;
        }
        // lib.optionalAttrs isVm {
          "backdrop/screen0/monitorVirtual-1/workspace0/image-style" = 5;
          "backdrop/screen0/monitorVirtual-1/workspace0/last-image" = wallpaper;
        };
    }))
  ]
