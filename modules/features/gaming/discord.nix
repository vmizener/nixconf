/*
  feat/gaming/discord

Enables a Discord desktop client (`vesktop` or stock `discord`).

Exposes:

- flake.homeModules."common/options" (options.mod."feat/gaming/discord")
- flake.homeModules."feat/gaming/discord":
*/
{...}: let
  moduleName = "feat/gaming/discord";
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      client = lib.mkOption {
        type = lib.types.enum ["vesktop" "discord"];
        default = "vesktop";
        description = "Discord desktop client to install.";
      };
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.meta.imported = [moduleName];
    home.packages = lib.optional (cfg.client == "discord") pkgs.discord;
    programs.vesktop = lib.mkIf (cfg.client == "vesktop") {
      enable = true;
      settings = {
        discordBranch = "stable";
        hardwareAcceleration = true;
      };
    };
  };
}
