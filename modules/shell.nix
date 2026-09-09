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

          (python3.withPackages (ps:
            with ps; [
              black
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
