/*
  feat/desktop/manager/niri

Enables the Niri Wayland compositor and desktop environment.

Exposes:

- flake.homeModules."feat/desktop/manager/niri":
  - Configures Niri wayland compositor and startup applications.

- flake.nixosModules."feat/desktop/manager/niri":
  - Enables Niri wayland session and XDG desktop portals.
*/
{
  inputs,
  lib,
  ...
}: let
  moduleName = "feat/desktop/manager/niri";

  # Overrides niri-portals.conf from configPackages so FileChooser uses GTK
  # instead of xdg-desktop-portal-gnome (which requires Nautilus).
  niriPortalConfig = {
    default = lib.mkDefault ["gnome" "gtk"];
    "org.freedesktop.impl.portal.Access" = lib.mkDefault "gtk";
    "org.freedesktop.impl.portal.FileChooser" = lib.mkDefault "gtk";
    "org.freedesktop.impl.portal.Notification" = lib.mkDefault "gtk";
    "org.freedesktop.impl.portal.Secret" = lib.mkDefault "gnome-keyring";
  };
in {
  flake.homeModules."common/options" = {...}: {
    options.mod.${moduleName} = {
      extraConfig = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Any additional config entries to add";
      };
    };
  };
  flake.homeModules.${moduleName} = {
    config,
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};

    isNixOs = osConfig != null;
    osHasNiri = isNixOs && osConfig.mod.meta.has moduleName;
    useFlakeNiri = !isNixOs;
    isVm = isNixOs && osConfig.mod."feat/vm".isVm;

    hasMod = name: config.mod.meta.has name || (isNixOs && osConfig.mod.meta.has name);
    terminalDesktop = config.mod."common/mime".defaultDesktop "x-scheme-handler/terminal";
    launcherDesktop = config.mod."common/mime".defaultDesktop "x-scheme-handler/launcher";

    generatedKdl = pkgs.replaceVars ./generated.kdl {
      XWAYLAND_SATELLITE = lib.getExe pkgs.xwayland-satellite-unstable;
      VM_INPUT = lib.optionalString isVm (lib.removeSuffix "\n" ''
        input {
            mod-key "Alt"
            mod-key-nested "Mod5"
        }
      '');
      BIND_TERMINAL = lib.optionalString (terminalDesktop != null) ''Mod+Return hotkey-overlay-title="Open Terminal (${terminalDesktop})" repeat=false { spawn-sh "handlr launch x-scheme-handler/terminal"; }'';
      BIND_LAUNCHER = lib.optionalString (launcherDesktop != null) ''Mod+D hotkey-overlay-title="Open Launcher (${launcherDesktop})" repeat=false { spawn-sh "handlr launch x-scheme-handler/launcher"; }'';
      BIND_KANDO = lib.optionalString (hasMod "feat/desktop/launcher/kando") ''Mod+M hotkey-overlay-title="Open Kando Menu" repeat=false { spawn-sh r#"kando --menu "Main Menu""#; }'';
    };
  in {
    imports = lib.optional useFlakeNiri inputs.niri.homeModules.niri;
    config = lib.mkMerge [
      (lib.optionalAttrs useFlakeNiri {
        nixpkgs.overlays = [inputs.niri.overlays.niri];
        programs.niri = {
          enable = true;
          package = config.lib.nixGL.wrap pkgs.niri-unstable;
        };
        xdg.portal = {
          extraPortals = with pkgs; [
            gnome-keyring
            xdg-desktop-portal-gtk
          ];
          config.niri = niriPortalConfig;
          xdgOpenUsePortal = lib.mkDefault true;
        };
      })
      {
        mod.meta = {
          imported = [moduleName];
          asserts = ["pairedNixosFeat"];
        };
      }
      (lib.mkIf (!isNixOs || osHasNiri) {
        xdg.configFile = {
          "niri/config.kdl".source = config.mod.meta.link ./config.kdl;
          "niri/local.kdl".source = pkgs.writeText "local.kdl" cfg.extraConfig;
          "niri/generated.kdl".source = generatedKdl;
        };
        home.packages = with pkgs; [
          brightnessctl
          xwayland-satellite-unstable
        ];
        home.sessionVariables.NIXOS_OZONE_WL = lib.mkIf isNixOs "1";
        targets.genericLinux.nixGL.packages = inputs.nixgl.packages;
      })
    ];
  };

  flake.nixosModules.${moduleName} = {pkgs, ...}: let
    pkg = pkgs.niri-unstable;
  in {
    imports = [inputs.niri.nixosModules.niri];
    config = {
      mod.meta.imported = [moduleName];
      nixpkgs.overlays = [inputs.niri.overlays.niri];
      programs.niri = {
        enable = true;
        package = pkg;
      };
      xdg.portal = {
        extraPortals = [pkgs.xdg-desktop-portal-gtk];
        config.niri = niriPortalConfig;
      };
      environment = {
        sessionVariables.NIXOS_OZONE_WL = "1";
        systemPackages = with pkgs; [xwayland-satellite-unstable];
      };
    };
  };
}
