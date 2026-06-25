{lib, ...}: {
  ################
  # Global options

  # Automatically merge homeModules, similar to nixosModules
  options.flake.homeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = {};
    description = "Home-manager modules";
  };

  config = {
    ################
    # Home-Manager common options
    flake.homeModules."common/options" = {...}: {
      options.flakePath = lib.mkOption {
        type = lib.types.path;
        apply = builtins.toString;
        default = lib.warn "`flakePath` option is not set; symlink-based features may break" ./..;
        description = "Absolute path to the Nix flake.  Used by some home-manager features to symlink configs.";
      };
    };
  };
}
