/*
  feat/desktop-manager/niri

Enables the Niri Wayland compositor and desktop environment.

Exposes:

- flake.homeModules."feat/desktop-manager/niri":
  - Configures Niri wayland compositor and startup applications.

- flake.nixosModules."feat/desktop-manager/niri":
  - Enables Niri wayland session and UWSM integration.
*/
{inputs, ...}: {
  flake.homeModules."feat/desktop-manager/niri" = {
    config,
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: let
    isNixOs = osConfig != null;
    osNiriEnabled = isNixOs && osConfig.programs.niri.enable;
    useFlakeNiri = !isNixOs || (isNixOs && !osNiriEnabled);
  in {
    imports = lib.optional useFlakeNiri inputs.niri.homeModules.niri;
    config = lib.mkMerge [
      (lib.optionalAttrs useFlakeNiri {
        nixpkgs.overlays = [inputs.niri.overlays.niri];
        programs.niri = {
          enable = true;
          package = config.lib.nixGL.wrap pkgs.niri-unstable;
        };
      })
      {
        programs.niri.config = let
          toKdl = inputs.wrapper-modules.lib.toKdl;
          rawSettings = import ./_settings.nix {
            inherit osConfig lib pkgs;
            hmConfig = config;
          };
        in
          toKdl (_: {
            version = 1;
            content = rawSettings;
          });
        home.packages = with pkgs; [
          brightnessctl
          xwayland-satellite
        ];
        home.sessionVariables.NIXOS_OZONE_WL = lib.mkIf isNixOs "1";
        targets.genericLinux.nixGL.packages = inputs.nixgl.packages;
      }
    ];
  };

  flake.nixosModules."feat/desktop-manager/niri" = {pkgs, ...}: let
    pkg = pkgs.niri-unstable;
  in {
    imports = [inputs.niri.nixosModules.niri];
    config = {
      nixpkgs.overlays = [inputs.niri.overlays.niri];
      programs.niri = {
        enable = true;
        package = pkg;
      };
      programs.uwsm.waylandCompositors = {
        enable = true;
        niri = {
          compositorPrettyName = "Niri";
          compositorComment = "Niri compositor managed by UWSM";
          compositorBinPath = "${pkg}/bin/niri";
        };
      };
      environment = {
        sessionVariables.NIXOS_OZONE_WL = "1";
        systemPackages = with pkgs; [xwayland-satellite];
      };
      systemd.services.display-manager.environment = {
        XDG_CURRENT_DESKTOP = "X-NIXOS-SYSTEMD-AWARE";
      };
    };
  };
}
