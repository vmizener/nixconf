{
  hmConfig ? null,
  osConfig ? null,
  lib,
  pkgs,
}: let
  # Checks
  isNixOs = osConfig != null;
  isHm = hmConfig != null;
  isVm = isNixOs && osConfig.mod."feat/vm".isVm;

  # Settings
  cfg =
    if isHm
    then hmConfig.mod."feat/desktop/manager/xfce"
    else {wallpaper = null;};
  hasWallpaper = isHm && cfg.wallpaper != null;
  wallpaperRelPath = "wallpapers/${builtins.baseNameOf (toString cfg.wallpaper)}";
  wallpaper = "${hmConfig.xdg.dataHome}/${wallpaperRelPath}";

  mimeEntry = mimeType:
    if isHm
    then hmConfig.mod."common/mime".defaultDesktop mimeType
    else null;

  modKey =
    if isVm
    then "Alt"
    else "Super";

  termExec = pkgs.writeShellScript "xfce-terminal-exec" ''
    read -r -a cmd <<<"$(handlr get x-scheme-handler/terminal --json | jq -r .cmd)"
    exec "''${cmd[@]}" -e "$@"
  '';

  helpers = lib.filter (h: h.entry != null) [
    {
      category = "TerminalEmulator";
      entry = mimeEntry "x-scheme-handler/terminal";
      cmd = "handlr launch x-scheme-handler/terminal";
      cmdWithParam = ''${termExec} "%s"'';
      icon = "utilities-terminal";
    }
    {
      category = "WebBrowser";
      entry = mimeEntry "x-scheme-handler/http";
      cmd = "handlr launch x-scheme-handler/http";
      cmdWithParam = ''handlr launch x-scheme-handler/http -- "%s"'';
      icon = "web-browser";
    }
  ];

  mkHelper = {
    category,
    entry,
    cmd,
    cmdWithParam,
    icon,
  }: ''
    [Desktop Entry]
    NoDisplay=true
    Version=1.0
    Encoding=UTF-8
    Type=X-XFCE-Helper
    X-XFCE-Category=${category}
    X-XFCE-Commands=${cmd}
    X-XFCE-CommandsWithParameter=${cmdWithParam}
    Icon=${icon}
    Name=${entry}
  '';
in {
  xdg = {
    configFile = lib.optionalAttrs (helpers != []) {
      "xfce4/helpers.rc".text = lib.concatLines (map (h: "${h.category}=custom-${h.category}") helpers);
    };
    dataFile =
      lib.listToAttrs (map (h: {
          name = "xfce4/helpers/custom-${h.category}.desktop";
          value.text = mkHelper h;
        })
        helpers)
      // lib.optionalAttrs hasWallpaper {
        ${wallpaperRelPath}.source = cfg.wallpaper;
      };
  };
  xfconf = {
    enable = true;
    settings =
      lib.optionalAttrs (mimeEntry "x-scheme-handler/terminal" != null) {
        xfce4-keyboard-shortcuts = {
          "commands/custom/override" = true;
          "commands/custom/<${modKey}>Return" = "handlr launch x-scheme-handler/terminal";
        };
      }
      // lib.optionalAttrs hasWallpaper {
        xfce4-desktop =
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
      };
  };
}
