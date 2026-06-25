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
    flake.homeModules."common/options" = {config, ...}: {
      options.flakePath = lib.mkOption {
        type = lib.types.path;
        apply = builtins.toString;
        default = let
          path = (
            lib.lists.findFirst
            (path: builtins.pathExists path)
            (lib.warn "`flakePath` option unset; symlink features may break" null)
            [
              "/etc/nixos"
              "${config.xdg.configHome}/home-manager"
            ]
          );
        in
          if path == null
          then ./..
          else builtins.toPath path;
        description = "Absolute path to the Nix flake.  Used by some home-manager features to symlink configs.";
      };
    };
  };
}
