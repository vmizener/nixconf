/*
  feat/gaming/soh

Ship of Harkinian.

Exposes:

- flake.homeModules."feat/gaming/soh":
*/
{inputs, ...}: {
  flake.homeModules."common/options" = {lib, ...}: {
    options.features.gaming.soh = {
      gamepaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Images for Ship";
      };
    };
  };
  flake.homeModules."feat/gaming/soh" = {config, ...}: {
    imports = [inputs.soh-flake.homeManagerModules.default];
    programs.shipofharkinian = {
      enable = true;
      gamepaths = config.features.gaming.soh.gamepaths;
    };
    xdg.dataFile = {
      "shipofharkinian/shipofharkinian.json".source = config.mutableLink ./shipofharkinian.json;
    };
  };
}
