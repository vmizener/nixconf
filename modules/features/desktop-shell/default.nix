{lib, ...}: {
  flake.homeModules."common/options" = {...}: {
    options.features.desktop-shell = {
      launchers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Supported application launchers";
      };
    };
  };
}
