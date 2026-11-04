{
  hmConfig ? null,
  osConfig ? null,
  lib,
}: let
  # Checks
  isNixOs = osConfig != null;
  isHm = hmConfig != null;
  isVm = isNixOs && osConfig.mod."feat/vm".isVm;

  # Settings
  wallpaper = "${../../../../../assets/wallpapers/fog_forest.webp}";

  mimeEnabled = isHm && hmConfig.mod."feat/system/mime".enable;
  mimeDefault = mimeType: fallback: let
    entries = hmConfig.xdg.mimeApps.defaultApplications.${mimeType} or [];
  in
    if mimeEnabled && entries != []
    then lib.removeSuffix ".desktop" (builtins.head entries)
    else fallback;

  terminal = mimeDefault "x-scheme-handler/terminal" "st";
  browser = mimeDefault "x-scheme-handler/http" "firefox";
  modKey =
    if isVm
    then "Alt"
    else "Super";

  mkHelper = {
    category,
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
    Name=${cmd}
  '';
in {
  xdg = {
    configFile."xfce4/helpers.rc".text = ''
      TerminalEmulator=custom-TerminalEmulator
      WebBrowser=custom-WebBrowser
    '';
    dataFile = {
      "xfce4/helpers/custom-TerminalEmulator.desktop".text = mkHelper {
        category = "TerminalEmulator";
        cmd = terminal;
        cmdWithParam = "${terminal} -e %s";
        icon = "utilities-terminal";
      };
      "xfce4/helpers/custom-WebBrowser.desktop".text = mkHelper {
        category = "WebBrowser";
        cmd = browser;
        cmdWithParam = ''${browser} "%s"'';
        icon = "web-browser";
      };
    };
  };
  xfconf = {
    enable = true;
    settings = {
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
      xfce4-keyboard-shortcuts = {
        "commands/custom/override" = true;
        "commands/custom/<${modKey}>Return" = terminal;
      };
    };
  };
}
