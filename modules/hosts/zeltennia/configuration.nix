{
  self,
  inputs,
  ...
}: let
  hostname = "zeltennia";
in {
  flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules."host/${hostname}"
    ];
  };
  flake.nixosModules."host/${hostname}" = {...}: {
    imports = [
      self.nixosModules."common"
      self.nixosModules."hardware/${hostname}"

      self.nixosModules."users/bao@${hostname}"

      self.nixosModules."feat/system/locale"
      self.nixosModules."feat/system/systools"
    ];

    system.stateVersion = "25.11";
    networking.hostName = "${hostname}";
  };
}
