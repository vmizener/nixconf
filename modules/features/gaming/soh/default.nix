/*
  feat/gaming/soh

Ship of Harkinian.

Exposes:

- flake.homeModules."feat/gaming/soh":
*/
{inputs, ...}: let
  moduleName = "feat/gaming/soh";
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      gamepaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Images for Ship";
      };
    };
  };
  flake.homeModules.${moduleName} = {config, ...}: let
    cfg = config.mod.${moduleName};
  in {
    mod.imported = [moduleName];
    imports = [inputs.soh-flake.homeManagerModules.default];
    programs.shipofharkinian = {
      enable = true;
      gamepaths = cfg.gamepaths;
    };
  };
}
