{
  flake-parts-lib,
  inputs,
  lib,
  self,
  ...
}: let
  # Dynamically pick up all modules, ignoring those from these inputs
  ignoreInputs = [
    "nixconf"
    "nixpkgs"
    "self"
  ];
  pickModule = name: modSet:
    if modSet ? default # check for <module>.default
    then [modSet.default]
    else if modSet ? ${name} # check for <module>.<inputname>
    then [modSet.${name}]
    else [];
  collectModules = getModSet:
    lib.concatLists (
      lib.mapAttrsToList (
        name: inp:
          if builtins.elem name ignoreInputs
          then []
          else pickModule name (getModSet inp)
      )
      inputs
    );
  hmInputModules = collectModules (
    inp:
      inp.homeModules or inp.homeManagerModules or {}
  );
  hmOptionModules =
    [
      self.homeModules."common/options"
    ]
    ++ hmInputModules;
  nixosInputModules = collectModules (
    inp:
      inp.nixosModules or {}
  );
in {
  imports = [
    (flake-parts-lib.mkTransposedPerSystemModule {
      name = "nixdOptions";
      option = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = {};
        description = "Dummy NixOS and Home-Manager evaluations exposing option sets to nixd.";
      };
      file = ./nixd.nix;
    })
  ];

  ################
  # Dummy configs to expose options to nixd
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    nixdOptions = {
      home = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {osConfig = null;};
        modules =
          [
            {
              home.stateVersion = "25.11";
              home.username = "options";
              home.homeDirectory = "/home/options";
            }
          ]
          ++ hmOptionModules;
      };
      nixos = inputs.nixpkgs.lib.nixosSystem {
        modules =
          [
            {
              system.stateVersion = "25.11";
              nixpkgs.hostPlatform = system;
              home-manager = {
                useGlobalPkgs = true;
                sharedModules = hmOptionModules;
              };
            }
            self.nixosModules."common/options"
          ]
          ++ nixosInputModules;
      };
    };
  };
}
