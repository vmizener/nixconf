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
        default = let
          candidates = [
            "/etc/nixos"
            "${config.xdg.configHome}/home-manager"
          ];
          path = lib.lists.findFirst (p: builtins.pathExists p) null candidates;
          fallback = ./..;
        in
          if path == null
          then fallback
          else builtins.toPath path;
        description = "Absolute path to this Nix flake.  Used by some home-manager features to symlink configs.";
      };
    };
  };
}
