/*
  feat/desktop-manager/niri

Enables the Niri Wayland compositor and desktop environment.

Exposes:

- flake.homeModules."feat/desktop-manager/niri":
  - Configures Niri wayland compositor and startup applications.

- flake.nixosModules."feat/desktop-manager/niri":
  - Enables Niri wayland session and UWSM integration.
*/
{inputs, ...}: let
  niriSettings = import ./_settings.nix;
  niriPackage = osConfig: lib: pkgs:
    inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      runtimeLibs = with pkgs; [
        libdrm
        libGL
        libinput
        libX11
        libxcursor
        libXext
        libXfixes
        libXi
        libxkbcommon
        libXrandr
        libXrender
        mesa
        seatd
        udev
        vulkan-loader
      ];
      settings = niriSettings {inherit osConfig lib pkgs;};
    }
    // {
      cargoBuildNoDefaultFeatures = false;
      cargoBuildFeatures = [];
    };
in {
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
    pkg = niriPackage osConfig lib pkgs;
    niriHmConfig = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = niriSettings {
        inherit osConfig lib pkgs;
        hmConfig = config;
      };
    };
  in {
    imports = lib.optional useFlakeNiri inputs.niri.homeModules.niri;
    config = lib.mkMerge [
      (lib.optionalAttrs useFlakeNiri {
        nixpkgs.overlays = [inputs.niri.overlays.niri];
        programs.niri = {
          enable = true;
          package = config.lib.nixGL.wrap pkg;
        };
      })
      {
        programs.niri.config = niriHmConfig.generatedConfig;
        home.packages = with pkgs; [
          brightnessctl
          xwayland-satellite
        ];
        home.sessionVariables.NIXOS_OZONE_WL = lib.mkIf isNixOs "1";
        targets.genericLinux.nixGL.packages = inputs.nixgl.packages;
      }
    ];
  };

  flake.nixosModules."feat/desktop-manager/niri" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    pkg = niriPackage config lib pkgs;
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
