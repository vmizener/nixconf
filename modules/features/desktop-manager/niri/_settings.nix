{
  hmConfig ? null,
  osConfig ? null,
  lib,
  pkgs,
}: let
  # Checks
  isNixOs = osConfig != null;
  isHm = hmConfig != null;
  isVm = isNixOs && osConfig.features.vm.isVm;

  # Logic
  checkCfgs = checker: (isHm && checker hmConfig) || (isNixOs && checker osConfig);
  cmdByFeat = default: featList: (pkgs.lib.findFirst (f: checkCfgs f.checker) {cmd = default;} featList).cmd;
  hasFeat = feat: cfg: path: (lib.hasAttrByPath path cfg) && (builtins.elem feat (lib.attrByPath path null cfg));

  # Commands
  cmdTerminal = cmdByFeat "st" [
    {
      cmd = "foot";
      checker = cfg: hasFeat "foot" cfg ["features" "terminal" "emulators"];
    }
    {
      cmd = "kitty";
      checker = cfg: hasFeat "kitty" cfg ["features" "terminal" "emulators"];
    }
  ];
  cmdLauncher = cmdByFeat null [
    {
      cmd = "dms ipc spotlight open";
      checker = cfg: hasFeat "dms" cfg ["features" "desktop-shell" "launchers"];
    }
    {
      cmd = "fuzzel";
      checker = cfg: hasFeat "fuzzel" cfg ["features" "tools"];
    }
  ];
  cmdKandoMenu = cmdByFeat null [
    {
      cmd = ''kando --menu "Main Menu"'';
      checker = cfg: hasFeat "kando" cfg ["features" "tools"];
    }
  ];
  cmdAudioRaiseVolume = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+";
  cmdAudioLowerVolume = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-";
  cmdAudioMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
  cmdAudioMicMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";

  # KDL stuff
  toggle = _: {};
  propSet = p: _: {props = p;};
  block = c: _: c;
in [
  {
    spawn-at-startup = [
      "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=X-NIXOS-SYSTEMD-AWARE"
    ];
  }
  {
    environment = {
      DISPLAY = ":0";
      QT_QPA_PLATFORM = "wayland";
      WAYLAND_DISPLAY = "wayland-1";
      NIRI_NO_HARDWARE_CURSORS = "1";
    };
  }
  {
    input =
      {
        keyboard = {
          xkb.layout = "us";
          numlock = toggle;
        };
        touchpad = {
          tap = toggle;
          natural-scroll = toggle;
        };
        focus-follows-mouse = propSet {max-scroll-amount = "0%";};
      }
      // lib.optionalAttrs isVm {
        mod-key = "Alt";
        mod-key-nested = "Mod5";
      };
  }
  {
    layout = {
      gaps = 10;
      background-color = "transparent";
      center-focused-column = "never";
      always-center-single-column = toggle;
      preset-column-widths = [
        {proportion = 0.33333;}
        {proportion = 0.5;}
        {proportion = 0.66667;}
        {proportion = 1.0;}
      ];
      preset-window-heights = [
        {proportion = 0.5;}
        {proportion = 1.0;}
      ];
      focus-ring = {
        width = 4;
        active-color = "#7fc8ff44";
        inactive-color = "#50505055";
      };
      shadow = {
        on = toggle;
        softness = 30;
        spread = 5;
        offset = propSet {
          x = 0;
          y = 5;
        };
        color = "#0007";
      };
      tab-indicator = {
        hide-when-single-tab = toggle;
        place-within-column = toggle;
        gap = 5;
        width = 5;
        length = propSet {total-proportion = 1.0;};
        position = "right";
        gaps-between-tabs = 3;
        corner-radius = 8;
        active-gradient = propSet {
          from = "#80c8ff";
          to = "#bbddff";
          angle = 45;
        };
        inactive-gradient = propSet {
          from = "#505050";
          to = "#808080";
          angle = 45;
          relative-to = "workspace-view";
        };
        urgent-gradient = propSet {
          from = "#800";
          to = "#a33";
          angle = 45;
        };
      };
    };
  }
  {prefer-no-csd = toggle;}
  {screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";}
  {
    xwayland-satellite = {
      path = "${lib.getExe pkgs.xwayland-satellite}";
    };
  }
  {
    blur = {
      passes = 2;
      offset = 1.5;
      noise = 0.05;
      saturation = 1.5;
    };
  }
  {overview = {workspace-shadow = {off = toggle;};};}
  {
    binds = (
      {
        "Mod+Shift+Slash".show-hotkey-overlay = toggle;
        "Mod+Shift+O".toggle-window-rule-opacity = toggle;
        "Mod+O" = block {
          props = {repeat = false;};
          content = {toggle-overview = toggle;};
        };

        "Mod+Shift+Q".close-window = toggle;
        "Mod+Ctrl+MouseRight".close-window = toggle;

        "Mod+Left" = {focus-column-or-monitor-left = toggle;};
        "Mod+Right" = {focus-column-or-monitor-right = toggle;};
        "Mod+Up" = {focus-window-or-workspace-up = toggle;};
        "Mod+Down" = {focus-window-or-workspace-down = toggle;};
        "Mod+H" = {focus-column-or-monitor-left = toggle;};
        "Mod+L" = {focus-column-or-monitor-right = toggle;};
        "Mod+K" = {focus-window-or-workspace-up = toggle;};
        "Mod+J" = {focus-window-or-workspace-down = toggle;};

        "Mod+Ctrl+Left" = {move-column-left-or-to-monitor-left = toggle;};
        "Mod+Ctrl+Right" = {move-column-right-or-to-monitor-right = toggle;};
        "Mod+Ctrl+Up" = {move-window-up-or-to-workspace-up = toggle;};
        "Mod+Ctrl+Down" = {move-window-down-or-to-workspace-down = toggle;};

        "Mod+Ctrl+H" = {move-column-left-or-to-monitor-left = toggle;};
        "Mod+Ctrl+L" = {move-column-right-or-to-monitor-right = toggle;};
        "Mod+Ctrl+K" = {move-window-up-or-to-workspace-up = toggle;};
        "Mod+Ctrl+J" = {move-window-down-or-to-workspace-down = toggle;};

        "Mod+Shift+Left" = {focus-monitor-left = toggle;};
        "Mod+Shift+Right" = {focus-monitor-right = toggle;};
        "Mod+Shift+Up" = {focus-monitor-up = toggle;};
        "Mod+Shift+Down" = {focus-monitor-down = toggle;};
        "Mod+Shift+H" = {focus-monitor-left = toggle;};
        "Mod+Shift+L" = {focus-monitor-right = toggle;};
        "Mod+Shift+K" = {focus-monitor-up = toggle;};
        "Mod+Shift+J" = {focus-monitor-down = toggle;};
        "Mod+Shift+Ctrl+Left" = {move-column-to-monitor-left = toggle;};
        "Mod+Shift+Ctrl+Right" = {move-column-to-monitor-right = toggle;};
        "Mod+Shift+Ctrl+Up" = {move-column-to-monitor-up = toggle;};
        "Mod+Shift+Ctrl+Down" = {move-column-to-monitor-down = toggle;};
        "Mod+Shift+Ctrl+H" = {move-column-to-monitor-left = toggle;};
        "Mod+Shift+Ctrl+L" = {move-column-to-monitor-right = toggle;};
        "Mod+Shift+Ctrl+K" = {move-column-to-monitor-up = toggle;};
        "Mod+Shift+Ctrl+J" = {move-column-to-monitor-down = toggle;};

        "Mod+Home" = {focus-column-first = toggle;};
        "Mod+End" = {focus-column-last = toggle;};
        "Mod+Ctrl+Home" = {move-column-to-first = toggle;};
        "Mod+Ctrl+End" = {move-column-to-last = toggle;};

        "Mod+Page_Up" = {focus-workspace-up = toggle;};
        "Mod+Page_Down" = {focus-workspace-down = toggle;};
        "Mod+I" = {focus-workspace-up = toggle;};
        "Mod+U" = {focus-workspace-down = toggle;};
        "Mod+Ctrl+Page_Up" = {move-workspace-up = toggle;};
        "Mod+Ctrl+Page_Down" = {move-workspace-down = toggle;};
        "Mod+Ctrl+I" = {move-workspace-up = toggle;};
        "Mod+Ctrl+U" = {move-workspace-down = toggle;};
        "Mod+Shift+Ctrl+Page_Up" = {move-workspace-to-monitor-previous = toggle;};
        "Mod+Shift+Ctrl+Page_Down" = {move-workspace-to-monitor-next = toggle;};
        "Mod+Shift+Ctrl+I" = {move-workspace-to-monitor-previous = toggle;};
        "Mod+Shift+Ctrl+U" = {move-workspace-to-monitor-next = toggle;};

        "Mod+WheelScrollUp" = block {
          props = {cooldown-ms = 100;};
          content = {focus-workspace-up = toggle;};
        };
        "Mod+WheelScrollDown" = block {
          props = {cooldown-ms = 100;};
          content = {focus-workspace-down = toggle;};
        };
        "Mod+WheelScrollLeft" = block {
          props = {cooldown-ms = 100;};
          content = {focus-column-left = toggle;};
        };
        "Mod+WheelScrollRight" = block {
          props = {cooldown-ms = 100;};
          content = {focus-column-right = toggle;};
        };
        "Mod+Ctrl+WheelScrollUp" = block {
          props = {cooldown-ms = 100;};
          content = {focus-column-left-or-last = toggle;};
        };
        "Mod+Ctrl+WheelScrollDown" = block {
          props = {cooldown-ms = 100;};
          content = {focus-column-right-or-first = toggle;};
        };

        "Mod+Grave" = {focus-workspace-previous = toggle;};
        "Mod+Backslash" = {focus-workspace-previous = toggle;};

        "Mod+Tab" = {focus-window-or-workspace-down = toggle;};
        "Mod+Shift+Tab" = {focus-window-or-workspace-up = toggle;};
        "Mod+Ctrl+Tab" = {focus-column-right-or-first = toggle;};
        "Mod+Ctrl+Shift+Tab" = {focus-column-left-or-last = toggle;};

        "Mod+BracketLeft" = {consume-or-expel-window-left = toggle;};
        "Mod+BracketRight" = {consume-or-expel-window-right = toggle;};
        "Mod+Comma" = {consume-window-into-column = toggle;};
        "Mod+Period" = {expel-window-from-column = toggle;};

        "Mod+R" = {switch-preset-column-width = toggle;};
        "Mod+Shift+R" = {switch-preset-window-height = toggle;};
        "Mod+Ctrl+R" = {reset-window-height = toggle;};

        "Mod+F" = {maximize-window-to-edges = toggle;};
        "Mod+Shift+F" = {fullscreen-window = toggle;};
        "Mod+Ctrl+F" = {expand-column-to-available-width = toggle;};

        "Mod+C" = {center-column = toggle;};
        "Mod+Ctrl+C" = {center-visible-columns = toggle;};

        "Mod+Minus" = {set-column-width = "-10%";};
        "Mod+Equal" = {set-column-width = "+10%";};
        "Mod+Shift+Minus" = {set-window-height = "-10%";};
        "Mod+Shift+Equal" = {set-window-height = "+10%";};

        "Mod+Space" = {toggle-window-floating = toggle;};
        "Mod+Shift+Space" = {switch-focus-between-floating-and-tiling = toggle;};

        "Mod+W" = {toggle-column-tabbed-display = toggle;};

        "Print" = {screenshot = toggle;};
        "Ctrl+Print" = {screenshot-screen = toggle;};
        "Alt+Print" = {screenshot-window = toggle;};

        "Mod+Escape" = block {
          props = {allow-inhibiting = false;};
          content = {toggle-keyboard-shortcuts-inhibit = toggle;};
        };
        "Ctrl+Alt+Delete" = {quit = toggle;};
        "Mod+Ctrl+Shift+P" = {power-off-monitors = toggle;};
      }
      // lib.optionalAttrs (cmdTerminal != null) {
        "Mod+Return" = block {
          props = {
            hotkey-overlay-title = "Open Terminal: ${cmdTerminal}";
            repeat = false;
          };
          content = {spawn-sh = "${cmdTerminal}";};
        };
      }
      // lib.optionalAttrs (cmdLauncher != null) {
        "Mod+D" = block {
          props = {
            hotkey-overlay-title = "Open Launcher: ${cmdLauncher}";
            repeat = false;
          };
          content = {spawn-sh = "${cmdLauncher}";};
        };
      }
      // lib.optionalAttrs (cmdKandoMenu != null) {
        "Mod+M" = block {
          props = {
            hotkey-overlay-title = "Open Kando Menu";
            repeat = false;
          };
          content = {spawn-sh = "${cmdKandoMenu}";};
        };
      }
      // lib.optionalAttrs (cmdAudioRaiseVolume != null) {
        "XF86AudioRaiseVolume" = block {
          props = {allow-when-locked = true;};
          content = {spawn-sh = "${cmdAudioRaiseVolume}";};
        };
      }
      // lib.optionalAttrs (cmdAudioLowerVolume != null) {
        "XF86AudioLowerVolume" = block {
          props = {allow-when-locked = true;};
          content = {spawn-sh = "${cmdAudioLowerVolume}";};
        };
      }
      // lib.optionalAttrs (cmdAudioMute != null) {
        "XF86AudioMute" = block {
          props = {allow-when-locked = true;};
          content = {spawn-sh = "${cmdAudioMute}";};
        };
      }
      // lib.optionalAttrs (cmdAudioMicMute != null) {
        "XF86AudioMicMute" = block {
          props = {allow-when-locked = true;};
          content = {spawn-sh = "${cmdAudioMicMute}";};
        };
      }
    );
  }
  {
    window-rule = [
      {
        match = propSet {
          app-id = "^(|firefox|zen|zen-beta)#";
          title = "^Picture.in.[Pp]icture$";
        };
      }
      {
        default-floating-position = propSet {
          x = 0;
          y = 0;
          relative-to = "top-right";
        };
      }
      {default-column-width = {proportion = 0.5;};}
      {default-window-height = {proportion = 0.5;};}
      {open-floating = true;}
      {open-focused = false;}
    ];
  }
  {
    window-rule = [
      {
        match = propSet {
          is-focused = false;
          is-floating = true;
        };
      }
      {opacity = 0.6;}
    ];
  }
  {
    window-rule = [
      {match = propSet {app-id = "^mpv$";};}
      {open-floating = true;}
      {open-fullscreen = true;}
    ];
  }
  {
    window-rule = [
      {match = propSet {title = "^Kando Menu$";};}
      {border = {off = toggle;};}
      {focus-ring = {off = toggle;};}
      {shadow = {off = toggle;};}
      {
        default-floating-position = propSet {
          x = 0;
          y = 0;
        };
      }
      {open-floating = true;}
    ];
  }
  {
    window-rule = [
      {
        match = propSet {
          app-id = "google-chrome";
          title = "^Meet -.*$";
        };
      }
      {
        exclude = propSet {
          app-id = "google-chrome";
          title = "^Meet -.*- Google Chrome$";
        };
      }
      {
        default-floating-position = propSet {
          x = 10;
          y = 10;
          relative-to = "top-right";
        };
      }
      {default-column-width = {proportion = 0.5;};}
      {default-window-height = {proportion = 0.5;};}
      {open-floating = true;}
      {open-focused = false;}
    ];
  }
  {
    window-rule = [
      {
        match = propSet {
          app-id = "steam";
          title = "^Steam$";
        };
      }
      {open-on-workspace = "steam";}
      {default-column-width = {proportion = 0.85;};}
      {open-floating = false;}
    ];
  }
  {
    window-rule = [
      {
        match = propSet {
          app-id = "steam";
          title = "^Friends List$";
        };
      }
      {open-on-workspace = "steam";}
      {default-column-width = {proportion = 0.15;};}
      {open-floating = false;}
    ];
  }
  {
    window-rule = [
      {
        match = propSet {
          app-id = "steam";
          title = "^notificationtoasts_\d+_desktop$";
        };
      }
      {
        default-floating-position = propSet {
          x = 10;
          y = 50;
          relative-to = "bottom-right";
        };
      }
      {open-floating = true;}
      {open-focused = false;}
    ];
  }
  {
    window-rule = [
      {
        match = propSet {
          app-id = "dota2";
          title = "^Dota 2$";
        };
      }
      {open-maximized = true;}
      {open-fullscreen = true;}
    ];
  }
  {
    window-rule = [
      {match = propSet {app-id = "steam_app_686060";};} # Mewgenics
      {open-fullscreen = true;}
      {open-floating = false;}
    ];
  }
  {
    window-rule = [
      {match = propSet {app-id = "^Slay the Spire 2$";};}
      {open-floating = false;}
    ];
  }
  {
    window-rule = [
      {match = propSet {app-id = "qemu";};}
      {open-maximized = true;}
    ];
  }
  {
    window-rule = [
      {match = propSet {app-id = "^discord$";};}
      {open-maximized = true;}
    ];
  }
  {
    window-rule = [
      {match = propSet {app-id = "^foot$";};}
      {clip-to-geometry = true;}
      {
        background-effect = {
          blur = true;
          xray = false;
        };
      }
    ];
  }
  {
    layer-rule = [
      {match = propSet {namespace = "^awww-daemon$";};}
      {place-within-backdrop = true;}
    ];
  }
  {
    layer-rule = [
      {match = propSet {namespace = "^dms:bar$";};}
      {
        background-effect = {
          blur = true;
          xray = false;
        };
      }
    ];
  }
]
