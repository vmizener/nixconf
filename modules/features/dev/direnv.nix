/*
  feat/dev/direnv

Enables `direnv` automatic directory environment switching with `nix-direnv`
caching and shell integration.

Exposes:

- flake.homeModules."feat/dev/direnv":
  - Enables `programs.direnv` with `nix-direnv` and concise log filtering.
*/
{...}: let
  moduleName = "feat/dev/direnv";
in {
  flake.homeModules.${moduleName} = {lib, ...}: {
    mod.meta.imported = [moduleName];
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config.global.log_filter = lib.mkDefault "^loading";
    };
  };
}
