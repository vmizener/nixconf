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
    # (this doesn't work; pending https://github.com/NixOS/nix/pull/8892)
    flake.schemas = inputs.flake-schemas.schemas;

    # Define standard formatter & pre-commit hooks
    perSystem = {pkgs, ...}: {
      formatter = pkgs.alejandra;

      pre-commit = {
        check.enable = true;
        settings.hooks = {
          # Format check
          alejandra.enable = true;
        };
      };
    };
  };
}
