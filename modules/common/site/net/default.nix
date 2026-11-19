/*
  common/site/net

Cross-host network topology, domain policy & tag registry, static IPv4
assignment, merged DNS record synthesis (`options.site.net`), and host-local
proxy/SSO/VPN/DNS brokering (`options.mod."common/site/net"`).

Exposes:

- options.site.net
- flake.nixosModules."common/options" (options.mod."common/site/net")
- flake.nixosModules."common/site/net"
*/
{lib, ...} @ flake: let
  moduleName = "common/site/net";
  siteNet = flake.config.site.net;
  netOptions = import ./_options.nix {inherit lib siteNet;};
  dns = import ./_dns.nix {inherit lib siteNet;};
  mkPreset = lib.mkOverride 1100;
in {
  options.site.net = netOptions.site;

  config = {
    site.net = {
      domains.lan = {
        tags = mkPreset ["lan"];
        access = mkPreset "lan";
        tls = mkPreset "internal";
        defaultAuth = mkPreset "none";
        publishHosts = mkPreset true;
        splitDns = mkPreset true;
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
      hostCfg = siteNet.hosts.${hostName} or null;
      inherit (config.mod.meta) isVm;
    in {
      mod = {
        meta.imported = [moduleName];
        ${moduleName} = {
          trustedCidrs = [
            "127.0.0.0/8"
            "::1/128"
            "10.0.0.0/8"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "fd00::/8"
          ];
          dnsRecords = lib.mkIf (hostCfg != null && hostCfg.ipv4 != null) (
            netCfg.services
            |> lib.filterAttrs (
              _: svc: svc.domain != null && lib.hasInfix "." (siteNet.lib.extractHostname (siteNet.lib.qualifyService svc))
            )
            |> lib.mapAttrs' (
              _: svc:
                lib.nameValuePair (siteNet.lib.extractHostname (siteNet.lib.qualifyService svc)) (lib.mkDefault hostCfg.ipv4)
            )
          );
        };
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
        inherit hostCfg hostName isVm lib netCfg siteNet;
      };
    };
  };
}
