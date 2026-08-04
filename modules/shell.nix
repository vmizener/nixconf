{...}: {
  config = {
    perSystem = {
      pkgs,
      config,
      ...
    }: {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          pre-commit
        ];
        shellHook = ''
          ${config.pre-commit.installationScript}
        '';
      };
    };
  };
}
