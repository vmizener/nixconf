/*
  feat/gaming/harbourmasters

HarbourMasters64 projects

Exposes:

- flake.homeModules."feat/gaming/harbourmasters":
*/
{inputs, ...}: let
  moduleName = "feat/gaming/harbourmasters";

  projects = [
    "shipofharkinian"
    "ghostship"
  ];
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = lib.genAttrs projects (project: {
      enable = lib.mkEnableOption "HarbourMasters project: ${project}";
      gamepaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Images to include";
      };
    });
  };
  flake.homeModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.imported = [moduleName];
    imports = [inputs.hm64-flake.homeManagerModules.default];
    programs.harbourmasters = lib.mkMerge (map (
        project:
          lib.mkIf cfg.${project}.enable {
            ${project} = {
              enable = true;
              gamepaths = cfg.${project}.gamepaths;
            };
          }
      )
      projects);
  };
}
