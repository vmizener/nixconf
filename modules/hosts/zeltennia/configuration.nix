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

      self.nixosModules."feat/net/blocky"
      self.nixosModules."feat/net/caddy"
      self.nixosModules."feat/net/mdns"
      self.nixosModules."feat/system/locale"
      self.nixosModules."feat/system/systools"
      self.nixosModules."feat/vm"
    ];
    mod = {
      net = {
        interface = "enu1u1";
        ipv4 = "192.168.86.25";
        gateway = "192.168.86.1";
        nameservers = ["192.168.86.1"];
      };
      "feat/system/systools".categories = ["core" "sysadmin"];
      "feat/vm".autologinUser = "bao";
    };

    system.stateVersion = "25.11";
    networking.hostName = "${hostname}";
  };
}
