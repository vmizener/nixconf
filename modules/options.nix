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
    flake.homeModules."common/options" = {config, osConfig ? null, ...}: {
      options.flakePath = lib.mkOption {
        type = lib.types.path;
        default = if osConfig != null then "/etc/nixos" else "${config.xdg.configHome}/home-manager";
        description = "Absolute path to this Nix flake (outside Nix store).  Used for out-of-store symlinks.";
      };
    };
  };
}
