/*
  feat/shell

Provides interactive shell environments via selection (see subfeatures for options).

Exposes:

- flake.nixosModules."feat/shell":
  - Selector module for NixOS shells (defaults to zsh).

- flake.homeModules."feat/shell":
  - Selector module for Home Manager shells (defaults to zsh).
*/
{ self, ... }: {
  flake.homeModules = self.lib.mkSelectorFeature {
    featureName = "shell";
    defaultSelection = "zsh";
    target = "homeModules";
    isMulti = true;
  };
  flake.nixosModules = self.lib.mkSelectorFeature {
    featureName = "shell";
    defaultSelection = "zsh";
    target = "nixosModules";
    isMulti = true;
  };
}
