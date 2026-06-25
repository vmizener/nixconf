{lib, ...}: {
  flake.homeModules."common/options" = {...}: {
    options.features.tools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Supported tools";
    };
  };
  flake.nixosModules."common/options" = {...}: {
    options.features.tools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Supported tools";
    };
  };
}
