/*
  feat/gaming/harbourmasters

HarbourMasters64 projects

Exposes:

- flake.homeModules."feat/gaming/harbourmasters":
*/
{inputs, ...}: let
  moduleName = "feat/gaming/harbourmasters";
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      soh.gamepaths = lib.mkOption {
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
    imports = [inputs.hm64-flake.homeManagerModules.default];
    programs.harbourmasters.shipofharkinian = {
      enable = true;
      gamepaths = cfg.soh.gamepaths;
    };
  };
}
