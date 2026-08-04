{inputs, ...}: {
  imports = [
    inputs.git-hooks-nix.flakeModule
  ];

  config = {
    # Declare supported systems
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    # Expose schemas output from flake-schemas
    flake.schemas = inputs.flake-schemas.schemas;

    # Define standard formatter & pre-commit hooks
    perSystem = {pkgs, ...}: {
      formatter = pkgs.alejandra;

      pre-commit = {
        check.enable = true;
        settings.hooks = {
          # Format check
          alejandra.enable = true;
          # Flake check
          nix-flake-check = {
            enable = true;
            name = "nix flake check";
            entry = "sh -c 'if [ -z \"$NIX_BUILD_TOP\" ]; then nix flake check; fi'";
            pass_filenames = false;
          };
        };
      };
    };
  };
}
