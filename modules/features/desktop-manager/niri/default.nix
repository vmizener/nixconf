/*
  feat/desktop-manager/niri

Enables the Niri Wayland compositor and desktop environment.

Exposes:

- flake.homeModules."feat/desktop-manager/niri":
  - Configures Niri wayland compositor and startup applications.

- flake.nixosModules."feat/desktop-manager/niri":
  - Enables Niri wayland session and UWSM integration.
*/
{ inputs, self, ... }:
let
  package = "local/niri";
  localPkg = pkgs: self.packages.${pkgs.stdenv.hostPlatform.system}.${package} // {
    cargoBuildNoDefaultFeatures = false;
    cargoBuildFeatures = [];
  };
  niriSettings = import ./_config.nix;
in
{
  flake.homeModules."feat/desktop-manager/niri" = { config, lib, osConfig ? null, pkgs, ... }: let
    isNixOs = osConfig != null;
    useFlake = if isNixOs then !osConfig.programs.niri.enable else true;
  in {
    imports = lib.optional useFlake inputs.niri.homeModules.niri;
    config = lib.mkMerge [
      (lib.optionalAttrs useFlake {
        nixpkgs.overlays = [ inputs.niri.overlays.niri ];
        programs.niri = {
          enable = true;
          package = config.lib.nixGL.wrap (localPkg pkgs);
        };
      })
      {
        home.packages = with pkgs; [
          brightnessctl
          xwayland-satellite
        ];
        home.sessionVariables.NIXOS_OZONE_WL = lib.mkIf isNixOs "1";
        targets.genericLinux.nixGL.packages = inputs.nixgl.packages;
      }
    ];
  };

  flake.nixosModules."feat/desktop-manager/niri" = { pkgs, ... }: {
    imports = [ inputs.niri.nixosModules.niri ];
    config = {
      nixpkgs.overlays = [ inputs.niri.overlays.niri ];
      programs.niri = {
        enable = true;
        package = localPkg pkgs;
      };
      programs.uwsm.waylandCompositors = {
        enable = true;
        niri = {
          compositorPrettyName = "Niri";
          compositorComment = "Niri compositor managed by UWSM";
          compositorBinPath = "${localPkg}/bin/niri";
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

  perSystem = { config, lib, pkgs, ... }: {
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
      settings = niriSettings config lib pkgs;
    };
  };
}
