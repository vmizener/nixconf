/*
  feat/gaming/discord

Discord.

Exposes:

- flake.homeModules."feat/gaming/discord":
*/
{...}: let
  moduleName = "feat/gaming/discord";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    flake.imported = [moduleName];
    home.packages = with pkgs; [
      discord
    ];
    programs.vesktop = {
      enable = true;
      settings = {
        discordBranch = "stable";
        hardwareAcceleration = true;
      };
    };
  };
}
