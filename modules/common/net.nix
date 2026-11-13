{
  config,
  lib,
  ...
}: let
  moduleName = "common/net";
  flakeNet = config.inventory.net;
in {
  # Cross-host network topology, service discovery, and DNS registry
  options.inventory.net = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "lan";
      description = "Base domain for internal Blocky/Caddy virtual hosts (while .local is used by mDNS)";
    };
    publicDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "example.com";
      description = "Public base domain for internet-exposed services (`visibility = \"public\"`)";
    };
    proxyHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Hostname running the reverse proxy (Caddy) for inventory.net.hosts.*.services";
    };
    hosts = lib.mkOption {
      default = {};
      description = "Per-host static IP, DNS record, and reverse-proxy service inventory";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            interface = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Network interface name for static IPv4 assignment (e.g. 'eno1', 'end0', 'eth0')";
            };
            ipv4 = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Static LAN IPv4 address assigned to this host";
            };
            prefixLength = lib.mkOption {
              type = lib.types.ints.between 1 32;
              default = 24;
              description = "Subnet prefix length for the static IPv4 address";
            };
            gateway = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Default IPv4 gateway address";
            };
            nameservers = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "DNS nameservers to configure on this host";
            };
            dnsRecords = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = {};
              description = "Additional DNS hostname-to-IPv4 mappings published by this host";
            };
            services = lib.mkOption {
              default = {};
              description = "Network services exposed by this host for reverse proxying";
              type = lib.types.attrsOf (
                lib.types.submodule ({
                  config,
                  name,
                  ...
                }: {
                  options = {
                    port = lib.mkOption {
                      type = lib.types.port;
                      description = "Port the service listens on";
                    };
                    subdomain = lib.mkOption {
                      type = lib.types.str;
                      default = name;
                      description = "Subdomain or hostname to expose on the reverse proxy";
                    };
                    protocol = lib.mkOption {
                      type = lib.types.enum ["http" "https"];
                      default = "http";
                      description = "Upstream protocol used by the service";
                    };
                    visibility = lib.mkOption {
                      type = lib.types.enum ["lan" "public"];
                      default = "lan";
                      description = "Whether the service is restricted to the LAN (`.lan`) or exposed on `publicDomain`";
                    };
                    auth = lib.mkOption {
                      type = lib.types.enum ["sso" "none"];
                      default =
                        if config.visibility == "public"
                        then "sso"
                        else "none";
                      defaultText = lib.literalExpression ''if config.visibility == "public" then "sso" else "none"'';
                      description = "Proxy authentication policy enforced by Caddy before `reverse_proxy`";
                    };
                  };
                })
              );
            };
          };
        }
      );
    };

    # Readonly options
    allDnsRecords = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Merged DNS records across inventory.net.hosts and proxied services";
    };
    lib = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      readOnly = true;
      internal = true;
      description = "Helper functions for parsing and qualifying inventory.net hostnames";
    };
  };

  config = {
    ################
    # Flake-level network helpers & merged DNS records
    inventory.net = {
      lib = rec {
        extractHostname = key: let
          noHttp = lib.removePrefix "http://" (lib.removePrefix "https://" key);
        in
          builtins.head (lib.splitString ":" noHttp);

        qualifyKeyFor = baseDomain: key: let
          hostPart = extractHostname key;
        in
          if lib.hasInfix "." hostPart || baseDomain == null
          then key
          else builtins.replaceStrings [hostPart] ["${hostPart}.${baseDomain}"] key;

        qualifyKey = qualifyKeyFor flakeNet.domain;

        qualifyService = svc:
          qualifyKeyFor (
            if svc.visibility == "public"
            then flakeNet.publicDomain
            else flakeNet.domain
          )
          svc.subdomain;
      };

      allDnsRecords = let
        inherit (flakeNet.lib) extractHostname qualifyService;
        proxyIpv4 =
          if flakeNet.proxyHost != null
          then (flakeNet.hosts.${flakeNet.proxyHost} or {}).ipv4 or null
          else null;

        hostRecords =
          lib.foldlAttrs (
            acc: host: h:
              acc
              // lib.optionalAttrs (h.ipv4 != null) {"${host}.${flakeNet.domain}" = h.ipv4;}
              // h.dnsRecords
          ) {}
          flakeNet.hosts;

        serviceRecords = lib.optionalAttrs (proxyIpv4 != null) (
          lib.foldlAttrs (
            acc: _: h:
              acc
              // (
                h.services
                |> lib.filterAttrs (_: svc: lib.hasInfix "." (extractHostname (qualifyService svc)))
                |> lib.mapAttrs' (
                  _: svc:
                    lib.nameValuePair (extractHostname (qualifyService svc)) proxyIpv4
                )
              )
          ) {}
          flakeNet.hosts
        );
      in
        hostRecords // serviceRecords;
    };

    ################
    # NixOS static IP setup & cross-host collision assertions
    flake.nixosModules.${moduleName} = {
      config,
      lib,
      ...
    }: let
      hostName = config.networking.hostName;
      hostCfg = flakeNet.hosts.${hostName} or null;
      isVm = config.mod."feat/vm".isVm or false;
    in {
      mod.meta.imported = [moduleName];

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

      assertions = let
        inherit (flakeNet.lib) extractHostname qualifyService;

        duplicatesBy = keyFn: items:
          builtins.groupBy keyFn items
          |> lib.filterAttrs (_: group: builtins.length group > 1);

        proxyIpv4 =
          if flakeNet.proxyHost != null
          then (flakeNet.hosts.${flakeNet.proxyHost} or {}).ipv4 or null
          else null;

        ipv4Collisions =
          lib.mapAttrsToList (host: h: {
            inherit host;
            inherit (h) ipv4;
          })
          flakeNet.hosts
          |> builtins.filter (e: e.ipv4 != null)
          |> duplicatesBy (e: e.ipv4);

        serviceEntries =
          lib.mapAttrsToList (
            host: h:
              lib.mapAttrsToList (svcName: svc: let
                key = qualifyService svc;
                fqdn = extractHostname key;
              in {
                inherit fqdn key svc;
                source = "${host}.${svcName}";
              })
              h.services
          )
          flakeNet.hosts
          |> lib.concatLists;

        publicServices = builtins.filter (e: e.svc.visibility == "public") serviceEntries;
        serviceCollisions = duplicatesBy (e: e.key) serviceEntries;

        hostDnsEntries =
          lib.mapAttrsToList (
            host: h: let
              records =
                (lib.optionalAttrs (h.ipv4 != null) {"${host}.${flakeNet.domain}" = h.ipv4;})
                // h.dnsRecords;
            in
              lib.mapAttrsToList (fqdn: ip: {
                inherit fqdn ip;
                source = "${host} (${ip})";
              })
              records
          )
          flakeNet.hosts
          |> lib.concatLists;

        serviceDnsEntries =
          lib.optionalAttrs (proxyIpv4 != null) (
            serviceEntries
            |> builtins.filter (e: lib.hasInfix "." e.fqdn)
            |> builtins.groupBy (e: e.fqdn)
          )
          |> lib.mapAttrsToList (fqdn: entries: {
            inherit fqdn;
            ip = proxyIpv4;
            source = "service ${lib.concatMapStringsSep "/" (e: e.source) entries} (${proxyIpv4})";
          });

        dnsCollisions = duplicatesBy (e: e.fqdn) (hostDnsEntries ++ serviceDnsEntries);
      in
        [
          {
            assertion = flakeNet.publicDomain == null || flakeNet.publicDomain != flakeNet.domain;
            message = "inventory.net.publicDomain ('${toString flakeNet.publicDomain}') must differ from internal inventory.net.domain ('${flakeNet.domain}').";
          }
          {
            assertion = flakeNet.proxyHost == null || flakeNet.hosts ? ${flakeNet.proxyHost};
            message = "inventory.net.proxyHost '${toString flakeNet.proxyHost}' is not declared in inventory.net.hosts.";
          }
          {
            assertion = serviceEntries == [] || flakeNet.proxyHost != null;
            message = "inventory.net.hosts defines services, but inventory.net.proxyHost is not set.";
          }
        ]
        ++ lib.optional (hostCfg != null && hostCfg.ipv4 != null && !isVm) {
          assertion = hostCfg.interface != null;
          message = "inventory.net.hosts.${hostName}.interface must be set when ipv4 is specified.";
        }
        ++ lib.concatMap (e: [
          {
            assertion = lib.hasInfix "." e.fqdn;
            message = "inventory.net.hosts.${e.source}: visibility = \"public\" requires inventory.net.publicDomain to be set (or an explicit FQDN in subdomain).";
          }
          {
            assertion = !(e.fqdn == flakeNet.domain || lib.hasSuffix ".${flakeNet.domain}" e.fqdn);
            message = "inventory.net.hosts.${e.source}: public service hostname '${e.fqdn}' cannot use internal domain '.${flakeNet.domain}'.";
          }
        ])
        publicServices
        ++ lib.mapAttrsToList (ip: entries: {
          assertion = false;
          message = "inventory.net.hosts: static IPv4 '${ip}' is assigned to multiple hosts: ${lib.concatMapStringsSep ", " (e: e.host) entries}";
        })
        ipv4Collisions
        ++ lib.mapAttrsToList (key: entries: {
          assertion = false;
          message = "inventory.net.hosts: colliding service subdomain '${key}' declared by multiple services: ${lib.concatMapStringsSep ", " (e: e.source) entries}";
        })
        serviceCollisions
        ++ lib.mapAttrsToList (fqdn: entries: {
          assertion = false;
          message = "inventory.net.allDnsRecords: colliding DNS record '${fqdn}' published by multiple sources: ${lib.concatMapStringsSep ", " (e: e.source) entries}";
        })
        dnsCollisions;
    };
  };
}
