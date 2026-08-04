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
    flake.homeModules."common/options" = {
      config,
      osConfig ? null,
      ...
    }: {
      options.flakePath = lib.mkOption {
        type = lib.types.str;
        default =
          if osConfig != null
          then "/etc/nixos"
          else "${config.xdg.configHome}/home-manager";
        description = "Absolute path to this Nix flake (outside Nix store).  Used for out-of-store symlinks.";
      };

      options.mutableLink = lib.mkOption {
        default = filepath: let
          relpath = lib.removePrefix "./" (lib.path.removePrefix ./.. filepath);
        in
          config.lib.file.mkOutOfStoreSymlink "${config.flakePath}/${relpath}";
        description = "Make a mutable symlink path to the given config source";
        readOnly = true;
      };
    };
  };
}
