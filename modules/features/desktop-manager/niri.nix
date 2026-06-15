{ self, inputs, ... }:
let
  package = "local/niri";
in
{
  flake.homeModules = self.lib.mkSelectorChoice {
    featureName = "desktop-manager";
    selectionName = "niri";
    target = "homeModules";
    module = { osConfig ? null, lib, pkgs, ... }: let
      isNixOs = osConfig != null;
    in {
      imports = [ inputs.niri.homeModules.niri ];
      config = {
        programs.niri = {
          enable = true;
          settings = {
            environment = {
              DISPLAY = ":0";
              QT_QPA_PLATFORM = "wayland";
              NIRI_NO_HARDWARE_CURSORS = "1";
              WAYLAND_DISPLAY = "wayland-1";
            };
            input.keyboard = {
              xkb.layout = "us";
            };
            spawn-at-startup = [
              "${lib.getExe pkgs.foot}"
            ];
          };
        };
        environment ={
          sessionVariables.NIXOS_OZONE_WL = lib.mkIf isNixOs "1";
          systemPackages = with pkgs; [ xwayland-satellite ];
        };
      };
    };
  };

  flake.nixosModules = self.lib.mkSelectorChoice {
    featureName = "desktop-manager";
    selectionName = "niri";
    target = "nixosModules";
    module = { pkgs, ... }: let
      localPkg = self.packages.${pkgs.stdenv.hostPlatform.system}.${package} //{
        cargoBuildNoDefaultFeatures = false;
        cargoBuildFeatures = [];

      };
    in {
      imports = [ inputs.niri.nixosModules.niri ];
      config = {
        nixpkgs.overlays = [ inputs.niri.overlays.niri ];
        programs.niri = {
          enable = true;
          package = localPkg;
        };
        programs.uwsm.waylandCompositors = {
          enable = true;
          niri = {
            compositorPrettyName = "Niri";
            compositorComment = "Niri compositor managed by UWSM";
            compositorBinPath = "${localPkg}/bin/niri-session";
          };
        };
        environment ={
          sessionVariables.NIXOS_OZONE_WL = "1";
          systemPackages = with pkgs; [ xwayland-satellite ];
        };
        systemd.services.display-manager.environment = {
          XDG_CURRENT_DESKTOP = "X-NIXOS-SYSTEMD-AWARE";
        };
      };
    };
  };

  perSystem = { lib, pkgs, ... }: {
    packages.${package} = inputs.wrapper-modules.wrappers.niri.wrap {
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
      settings = {
        environment = {
          DISPLAY = ":0";
          QT_QPA_PLATFORM = "wayland";
          NIRI_NO_HARDWARE_CURSORS = "1";
          WAYLAND_DISPLAY = "wayland-1";
        };
        input.keyboard = {
          xkb.layout = "us";
        };
        spawn-at-startup = [
          "${lib.getExe pkgs.foot}"
        ];
      };
    };
  };
}
