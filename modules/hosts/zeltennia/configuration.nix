{
  self,
  inputs,
  ...
}: let
  hostname = "zeltennia";
in {
  inventory.net.hosts.${hostname} = {
    interface = "enu1u1";
    ipv4 = "192.168.86.25";
    gateway = "192.168.86.1";
    nameservers = [
      "127.0.0.1"
      "192.168.86.1"
    ];
    services = {
      auth = {
        port = 9091;
        domainTag = "sso";
        auth = "none";
      };
      headscale = {
        port = 8085;
        domainTag = "vpn";
        subdomain = "vpn";
        access = "public";
        auth = "none";
      };
    };
  };

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

      self.nixosModules."feat/net/authelia"
      self.nixosModules."feat/net/blocky"
      self.nixosModules."feat/net/caddy"
      self.nixosModules."feat/net/headscale"
      self.nixosModules."feat/net/mdns"
      self.nixosModules."feat/net/tailscale"
      self.nixosModules."feat/system/locale"
      self.nixosModules."feat/system/systools"
      self.nixosModules."feat/vm"
    ];
    mod = {
      "feat/net/caddy".acme.enable = true;
      "feat/net/tailscale" = {
        role = "router";
        advertiseRoutes = ["192.168.86.0/24"];
      };
      "feat/system/systools".categories = ["core" "sysadmin"];
      "feat/vm".autologinUser = "bao";
    };

    system.stateVersion = "25.11";
    networking.hostName = "${hostname}";
    users.mutableUsers = false;
  };
}
