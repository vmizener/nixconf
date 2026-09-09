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
    options.features.gaming.steam = {
      enableExtest = lib.mkOption {
        type = lib.types.bool;
        description = "Enable extest library (needed for Steam Input on Wayland)";
        default = false;
      };
    };
  };
  flake.nixosModules.${moduleName} = {
    config,
    pkgs,
    ...
  }: {
    flake.imported = [moduleName];
    programs.steam = {
      enable = true;
      extest.enable = config.features.gaming.steam.enableExtest;
      dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
      protontricks.enable = true; # Enable protontricks wrapper
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
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
