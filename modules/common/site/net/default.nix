/*
  common/site/net

Cross-host network topology, domain policy & tag registry, static IPv4
assignment, merged DNS record synthesis (`options.site.net`), and host-local
proxy/SSO/VPN/DNS/port brokering (`options.mod."common/site/net"`).

Port management model:
- Host-scoped, not flake-wide: ports are tracked per NixOS host under
  `mod."common/site/net".ports.<daemon>.{tcp,udp}` so independent hosts can
  freely reuse ports while catching `(proto, port)` collisions on each host.
  Cross-host port knowledge is limited to reverse-proxied upstreams under
  `site.net.hosts.<host>.services.<name>.port`.
- Explicit sockets only: feature modules register configurable or single-socket
  daemon ports (especially loopback daemons invisible to `networking.firewall`).
  Opaque upstream multi-port firewall presets (e.g. `services.sunshine`,
  `programs.steam.remotePlay`) and shared multicast sockets (e.g. mDNS 5353/udp)
  are intentionally left to nixpkgs rather than mirrored here.

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
      remoteProxiedPorts =
        if hostCfg != null && hostName != siteNet.proxyHost
        then lib.unique (map (svc: svc.port) (builtins.attrValues hostCfg.services))
        else [];
    in {
      mod = {
        meta.imported = [moduleName];
        "common/firewall" = {
          zones = {
            lan.cidrs = netCfg.trustedCidrs ++ lib.optional isVm "10.0.2.0/24";
            proxy.cidrs = lib.optional (siteNet.lib.proxyIpv4 != null) "${siteNet.lib.proxyIpv4}/32";
          };
          ingress.proxy-upstreams = lib.mkIf (remoteProxiedPorts != []) {
            zones = ["proxy"];
            tcp = remoteProxiedPorts;
            withoutProvider = "assert";
          };
        };
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
          # Seed `ports.<backend>.tcp` at `mkDefault` priority from proxied services on
          # this host so standalone `site.net.hosts` entries participate in collision
          # checks, while explicit `ports.<backend>.tcp` claims from feature modules
          # take precedence and let `_assertions.nix` detect proxy-vs-daemon port drift.
          ports = let
            localProxiedServices =
              lib.optionalAttrs (hostCfg != null) hostCfg.services
              // netCfg.services;
          in
            builtins.attrValues localProxiedServices
            |> builtins.groupBy (svc: svc.backend)
            |> builtins.mapAttrs (_: svcs: {
              tcp = lib.mkDefault (map (svc: svc.port) svcs);
            });
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
