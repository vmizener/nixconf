/*
  feat/gaming/steam

Steam.

Exposes:

- flake.nixosModules."feat/gaming/steam":
*/
{...}: let
  moduleName = "feat/gaming/steam";
in {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      enableExtest = lib.mkOption {
        type = lib.types.bool;
        description = "Enable extest library (needed for Steam Input on Wayland)";
        default = false;
      };
      openFirewall = {
        remotePlay = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to open firewall ports for Steam Remote Play";
        };
        dedicatedServer = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open firewall ports (27015 TCP/UDP) for Source Dedicated Server hosting";
        };
        localNetworkGameTransfers = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open firewall ports for Steam peer-to-peer LAN game transfers";
        };
      };
    };
  };
  flake.nixosModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod = {
      meta.imported = [moduleName];
      "common/site/net".ports.steam-dedicated = lib.mkIf cfg.openFirewall.dedicatedServer {
        tcp = [27015];
        udp = [27015];
      };
    };
    programs.steam = {
      enable = true;
      extest.enable = cfg.enableExtest;
      dedicatedServer.openFirewall = cfg.openFirewall.dedicatedServer;
      localNetworkGameTransfers.openFirewall = cfg.openFirewall.localNetworkGameTransfers;
      protontricks.enable = true; # Enable protontricks wrapper
      remotePlay.openFirewall = cfg.openFirewall.remotePlay;
      extraPackages = with pkgs; [
        hidapi # Steam Controller dependency
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
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
  };
}
