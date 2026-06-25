{lib, ...}: {
  flake.homeModules."common/options" = {...}: {
    options.features.terminal = {
      emulators = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Supported terminal emulators";
      };
    };
  };
}
