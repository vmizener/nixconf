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
          age
          pre-commit
          sops
          ssh-to-age

          (python3.withPackages (ps:
            with ps; [
              pillow
              ruamel-yaml
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
