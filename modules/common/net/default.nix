/*
  common/net

Cross-host network topology, domain policy & tag registry, static IPv4
assignment, merged DNS record synthesis, and host-local proxy/SSO/VPN/DNS
brokering (`options.mod."common/net"`).

Exposes:

- options.inventory.net
- flake.nixosModules."common/options" (options.mod."common/net")
- flake.nixosModules."common/net"
*/
{
  config,
  lib,
  ...
}: let
  moduleName = "common/net";
  flakeNet = config.inventory.net;
  netOptions = import ./_options.nix {inherit flakeNet lib;};
  dns = import ./_dns.nix {inherit flakeNet lib;};
in {
  options.inventory.net = netOptions.inventory;

  config = {
    inventory.net = {
      domains.lan = {
        tags = lib.mkDefault ["lan"];
        access = lib.mkDefault "lan";
        tls = lib.mkDefault "internal";
        defaultAuth = lib.mkDefault "none";
        publishHosts = lib.mkDefault true;
        splitDns = lib.mkDefault true;
      };
      lib = dns.netLib;
      inherit (dns) allDnsRecords;
    };

    flake.nixosModules."common/options" = {...}: {
      options.mod.${moduleName} = netOptions.mod;
    };

    flake.nixosModules.${moduleName} = {
      config,
      lib,
      ...
    }: let
      netCfg = config.mod.${moduleName};
      hostName = config.networking.hostName;
      hostCfg = flakeNet.hosts.${hostName} or null;
      isVm = config.mod."feat/vm".isVm or false;
    in {
      mod = {
        meta.imported = [moduleName];
        ${moduleName}.trustedCidrs = [
          "127.0.0.0/8"
          "::1/128"
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "fd00::/8"
        ];
      };

      networking = lib.mkIf (hostCfg != null && hostCfg.ipv4 != null && !isVm) {
        interfaces = lib.optionalAttrs (hostCfg.interface != null) {
          ${hostCfg.interface} = {
            useDHCP = false;
            ipv4.addresses = [
              {
                address = hostCfg.ipv4;
                inherit (hostCfg) prefixLength;
              }
            ];
          };
        };
        defaultGateway = lib.mkIf (hostCfg.gateway != null) hostCfg.gateway;
        nameservers = lib.mkIf (hostCfg.nameservers != []) hostCfg.nameservers;
      };

      assertions = import ./_assertions.nix {
        inherit dns flakeNet hostCfg hostName isVm lib netCfg;
      };
    };
  };
}
