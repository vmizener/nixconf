/*
  feat/io/kanshi

Enables the Kanshi display configuration tool.

Exposes:

- flake.homeModules."common/options" (options.mod."feat/io/kanshi")
- flake.homeModules."feat/io/kanshi":
*/
{...}: let
  moduleName = "feat/io/kanshi";
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      configFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Optional Kanshi configuration file included at the start of `services.kanshi.settings`.";
      };
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.meta.imported = [moduleName];
    services.kanshi = {
      enable = true;
      settings = lib.mkIf (cfg.configFile != null) (
        lib.mkBefore [
          {include = "${cfg.configFile}";}
        ]
      );
    };
  };
}
