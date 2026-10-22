{inputs, ...}: {
  imports = [
    inputs.git-hooks-nix.flakeModule
    inputs.treefmt-nix.flakeModule
  ];

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
          # Format check
          treefmt.enable = true;
        };
      };
    };
  };
}
