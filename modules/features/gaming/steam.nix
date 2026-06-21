/*
  feat/gaming/steam

Steam.

Exposes:

- flake.nixosModules."feat/gaming/steam":
*/
{
  flake.nixosModules."feat/gaming/steam" = {pkgs, ...}: {
    programs.steam = {
      enable = true;
      extest.enable = true; # Needed for Steam Input support on Wayland
      dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      extraPackages = with pkgs; [
        hidapi # Steam Controller dependency
      ];
    };
  };
}
