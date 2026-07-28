{inputs, ...}: {
  config = {
    # Declare supported systems
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    # Expose schemas output from flake-schemas
    flake.schemas = inputs.flake-schemas.schemas;

    # Define standard formatter
    perSystem = {pkgs, ...}: {
      # formatter = pkgs.nixpkgs-fmt;
      formatter = pkgs.alejandra;
    };
  };
}
