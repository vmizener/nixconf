{
  config = {
    # Declare supported systems
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    # Define standard formatter
    perSystem = {pkgs, ...}: {
      # formatter = pkgs.nixpkgs-fmt;
      formatter = pkgs.alejandra;
    };
  };
}
