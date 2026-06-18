/*
  feat/gaming/discord

Discord.

Exposes:

- flake.homeModules."feat/gaming/discord":
*/
{
  flake.homeModules."feat/gaming/discord" = { pkgs, ... }: {
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

