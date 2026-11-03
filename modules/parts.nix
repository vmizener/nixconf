{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.git-hooks-nix.flakeModule
    inputs.treefmt-nix.flakeModule
  ];

  options.flake = {
    # Automatically merge homeModules, similar to nixosModules
    homeModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = {};
      description = "Home-manager modules";
    };

    # Automatically merge homeConfigurations, similar to nixosConfigurations
    homeConfigurations = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
      description = "Home-manager configurations";
    };
  };

  config = {
    # Enable debug options
    debug = true;

    # Declare supported systems
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    # Expose schemas output from flake-schemas
    # (this doesn't work; pending https://github.com/NixOS/nix/pull/8892)
    flake.schemas = inputs.flake-schemas.schemas;

    # Define standard formatter & pre-commit hooks
    perSystem = {...}: {
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          alejandra.enable = true;
          black.enable = true;
          shfmt.enable = true;
          stylua = {
            enable = true;
            settings = {
              indent_type = "Spaces";
              indent_width = 2;
            };
          };
        };
      };

      pre-commit = {
        check.enable = true;
        settings.hooks = {
          shellcheck = {
            enable = true;
            exclude_types = ["zsh"];
          };
          treefmt.enable = true; # Format check
        };
      };
    };
  };
}
