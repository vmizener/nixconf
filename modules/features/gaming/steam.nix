/*
  feat/gaming/steam

Steam.

Exposes:

- flake.nixosModules."feat/gaming/steam":
*/
{
  flake.nixosModules."common/options" = {lib, ...}: {
    options.features.steam = {
      enableExtest = lib.mkOption {
        type = lib.types.bool;
        description = "Enable extest library (needed for Steam Input on Wayland)";
        default = false;
      };
    };
  };
  flake.nixosModules."feat/gaming/steam" = {config, pkgs, ...}: {
    programs.steam = {
      enable = true;
      extest.enable = config.features.steam.enableExtest;
      dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
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
    };
  };
}
