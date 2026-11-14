# Flake-level `options.inventory.net` schema for `common/net`.
{
  flakeNet,
  lib,
}: {
  defaultDomain = lib.mkOption {
    type = lib.types.str;
    default = "lan";
    description = "Default key in `inventory.net.domains` used when a service omits both `domain` and `domainTag`";
  };
  proxyHost = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Hostname running the reverse proxy (Caddy) for inventory.net.hosts.*.services";
  };
  vpnUrl = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "https://vpn.example.dev";
    description = "VPN coordination server URL used as the default `loginServer` across `feat/net/tailscale` hosts";
  };
  domains = lib.mkOption {
    default = {};
    description = "Named network domains and their role tags, reachability, TLS, authentication, and DNS policies";
    type = lib.types.attrsOf (
      lib.types.submodule ({config, ...}: {
        options = {
          tags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            apply = lib.unique;
            example = ["public" "sso"];
            description = "Role tags advertised by this domain (referenced via `domainTag` on services and feature modules)";
          };
          access = lib.mkOption {
            type = lib.types.enum ["lan" "public"];
            default = "lan";
            description = ''
              Default client reachability policy for virtual hosts in this domain:
              - `"lan"`: Restricted to `mod."feat/net/caddy".lanCidrs` (LAN + VPN).
              - `"public"`: Reachable from the public internet (opens WAN `httpsPort`).
            '';
          };
          tls = lib.mkOption {
            type = lib.types.enum ["internal" "acme"];
            default =
              if config.access == "public"
              then "acme"
              else "internal";
            defaultText = lib.literalExpression ''if config.access == "public" then "acme" else "internal"'';
            description = ''
              TLS certificate strategy for virtual hosts in this domain:
              - `"internal"`: Self-signed certificate from Caddy's local CA (`tls internal`).
              - `"acme"`: Public wildcard certificate (`<domain>` + `*.<domain>`) via `security.acme` DNS-01.
            '';
          };
          defaultAuth = lib.mkOption {
            type = lib.types.enum ["sso" "none"];
            default =
              if config.access == "public"
              then "sso"
              else "none";
            defaultText = lib.literalExpression ''if config.access == "public" then "sso" else "none"'';
            description = "Default proxy authentication policy inherited by services registered on this domain";
          };
          publishHosts = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to publish `<host>.<domain> -> ipv4` records in `allDnsRecords` for hosts with a static IPv4";
          };
          splitDns = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether VPN coordination servers (e.g. Headscale) route DNS queries for this domain to `proxyHost`";
          };
        };
      })
    );
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
              }: let
                domainCfg =
                  if config.domain != null
                  then flakeNet.domains.${config.domain} or null
                  else null;
              in {
                options = {
                  port = lib.mkOption {
                    type = lib.types.port;
                    description = "Port the service listens on";
                  };
                  domainTag = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    example = "dev";
                    description = "Select the unique domain in `inventory.net.domains` carrying this tag";
                  };
                  domain = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default =
                      if config.domainTag != null
                      then flakeNet.lib.resolveTag config.domainTag
                      else flakeNet.defaultDomain;
                    defaultText = lib.literalExpression ''
                      if config.domainTag != null
                      then config.inventory.net.lib.resolveTag config.domainTag
                      else config.inventory.net.defaultDomain
                    '';
                    description = "Target domain key in `inventory.net.domains` (resolved from `domainTag` or `defaultDomain` unless set explicitly)";
                  };
                  subdomain = lib.mkOption {
                    type = lib.types.str;
                    default = name;
                    description = "Subdomain label under `domain` (e.g. `\"vpn\"` -> `\"vpn.<domain>\"`, or `\"@\"` for the zone apex)";
                  };
                  protocol = lib.mkOption {
                    type = lib.types.enum ["http" "https"];
                    default = "http";
                    description = "Upstream protocol used by the service";
                  };
                  access = lib.mkOption {
                    type = lib.types.enum ["lan" "public"];
                    default =
                      if domainCfg != null
                      then domainCfg.access
                      else "lan";
                    defaultText = lib.literalExpression "config.inventory.net.domains.<domain>.access";
                    description = "Client reachability policy for this service (inherits from `domain` by default)";
                  };
                  auth = lib.mkOption {
                    type = lib.types.enum ["sso" "none"];
                    default =
                      if config.access == "public" && (domainCfg == null || domainCfg.access != "public")
                      then "sso"
                      else if domainCfg != null
                      then domainCfg.defaultAuth
                      else "none";
                    defaultText = lib.literalExpression ''
                      if config.access == "public" && domain.access != "public"
                      then "sso"
                      else config.inventory.net.domains.<domain>.defaultAuth
                    '';
                    description = "Proxy authentication policy enforced before `reverse_proxy`";
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
    description = "Helper functions for resolving domain tags and qualifying inventory.net hostnames";
  };
}
