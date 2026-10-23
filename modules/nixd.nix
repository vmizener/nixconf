{
  inputs,
  lib,
  self,
  ...
}: {
  ################
  # Dummy configs to expose options to nixd
  flake.nixdOptions = let
    # Dynamically pick up all modules, ignoring those from these inputs
    ignoreInputs = [
      "nixpkgs"
      "wrapper-modules"
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
    nixosInputModules = collectModules (
      inp:
        inp.nixosModules or {}
    );
  in {
    home = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
      extraSpecialArgs = {osConfig = null;};
      modules =
        [
          {
            home.stateVersion = "25.11";
            home.username = "options";
            home.homeDirectory = "/home/options";
          }
          self.homeModules."common/options"
        ]
        ++ hmInputModules;
    };
    nixos = inputs.nixpkgs.lib.nixosSystem {
      modules =
        [
          {
            system.stateVersion = "25.11";
            nixpkgs.hostPlatform = "x86_64-linux";
          }
          self.nixosModules."common/options"
        ]
        ++ nixosInputModules;
    };
  };
}
