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

    # Define standard formatter & pre-commit hook
    perSystem = {
      pkgs,
      config,
      ...
    }: {
      formatter = pkgs.alejandra;

      pre-commit = {
        check.enable = true;
        settings.hooks = {
          alejandra.enable = true;
        };
      };

      # Automatically install the pre-commit hook when entering dev-shell
      devShells.default = pkgs.mkShell {
        shellHook = ''
          ${config.pre-commit.installationScript}
        '';
      };
    };
  };
}
