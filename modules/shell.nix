{...}: {
  config = {
    perSystem = {
      pkgs,
      config,
      ...
    }: {
      devShells.default = pkgs.mkShell {
        inputsFrom = [
          config.treefmt.build.devShell
        ];
        packages = with pkgs; [
          pre-commit

          (python3.withPackages (ps:
            with ps; [
              pillow
              tomlkit
            ]))
        ];
        shellHook = ''
          ${config.pre-commit.shellHook}
        '';
      };
    };
  };
}
