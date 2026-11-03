{
  lib,
  self,
  ...
}: {
  # Evaluate standalone homeConfigurations matching each system in `nix flake check`
  perSystem = {system, ...}: {
    checks =
      self.homeConfigurations
      |> lib.filterAttrs (
        _: hmConf:
          hmConf.pkgs.stdenv.hostPlatform.system == system
      )
      |> lib.mapAttrs' (
        name: hmConf:
          lib.nameValuePair "hm:${name}" hmConf.activationPackage
      );
  };
}
