# Flake-level (`options.site.net`) and host-local (`options.mod."common/site/net"`)
# option schemas for `common/site/net`.
{
  lib,
  siteNet,
}: let
  serviceSubmodule = lib.types.submodule ({
    config,
    name,
    ...
  }: let
    domainCfg =
      if config.domain != null
      then siteNet.domains.${config.domain} or null
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
        description = "Select the unique domain in `site.net.domains` carrying this tag";
      };
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default =
          if config.domainTag != null
          then siteNet.lib.resolveTag config.domainTag
          else siteNet.defaultDomain;
        defaultText = lib.literalExpression ''
          if config.domainTag != null
          then config.site.net.lib.resolveTag config.domainTag
          else config.site.net.defaultDomain
        '';
        description = "Target domain key in `site.net.domains` (resolved from `domainTag` or `defaultDomain` unless set explicitly)";
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
      rootRedirect = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/admin";
        description = "Optional path target for HTTP 302 redirects from `/` before `reverse_proxy`";
      };
      access = lib.mkOption {
        type = lib.types.enum ["lan" "public"];
        default =
          if domainCfg != null
          then domainCfg.access
          else "lan";
        defaultText = lib.literalExpression "config.site.net.domains.<domain>.access";
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
          else config.site.net.domains.<domain>.defaultAuth
        '';
        description = "Proxy authentication policy enforced before `reverse_proxy`";
      };
    };
  });
in {
  # Cross-host topology & domain registry (`options.site.net`)
  site = {
    defaultDomain = lib.mkOption {
      type = lib.types.str;
      default = "lan";
      description = "Default key in `site.net.domains` used when a service omits both `domain` and `domainTag`";
    };
    proxyHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Hostname running the reverse proxy (Caddy) for `site.net.hosts.*.services`";
    };
    vpnUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = let
        vpnDomain = siteNet.lib.resolveTag "vpn";
      in
        if vpnDomain != null
        then "https://vpn.${vpnDomain}"
        else null;
      defaultText = lib.literalExpression ''
        let vpnDomain = config.site.net.lib.resolveTag "vpn";
        in if vpnDomain != null then "https://vpn.''${vpnDomain}" else null
      '';
      example = "https://vpn.example.dev";
      description = "VPN coordination server URL used as the default `loginServer` across `feat/net/tailscale` hosts";
    };
    adminEmails = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Admin identities (`user@domain`) granted VPN route/tag ownership (populated from `[net].admin_emails` in `site.meta.configFiles`)";
    };
    dns = lib.mkOption {
      default = {};
      description = "Named DNS provider accounts mapped 1:1 to `net/dns/<account>/` in `secrets.yaml` (populated from `[net.dns.<account>]` in `site.meta.configFiles`)";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            provider = lib.mkOption {
              type = lib.types.str;
              example = "porkbun";
              description = "Lego DNS-01 provider name for this account";
            };
          };
        }
      );
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
                - `"lan"`: Restricted to `mod."common/site/net".trustedCidrs` (LAN + VPN).
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
            dnsAccount = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "work";
              description = "Optional key in `site.net.dns` overriding the default ACME DNS-01 account for this domain";
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
              type = lib.types.attrsOf serviceSubmodule;
              description = "Network services exposed by this host for reverse proxying";
            };
          };
        }
      );
    };

    allDnsRecords = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Merged DNS records across `site.net.hosts` and proxied services";
    };
    lib = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      readOnly = true;
      internal = true;
      description = "Helper functions for resolving domain tags and qualifying `site.net` hostnames";
    };
  };

  # Host-local service broker (`options.mod."common/site/net"`)
  mod = {
    trustedCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      apply = lib.unique;
      description = "Trusted client CIDRs (loopback, RFC1918/ULA LAN, and local VPN prefixes) allowed to access `access = \"lan\"` services and HTTP port 80 (use `lib.mkForce` to replace defaults).";
    };

    dnsRecords = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Host-local DNS hostname-to-IPv4 mappings (e.g. explicit reverse-proxy virtual hosts) merged by local DNS resolvers.";
    };

    services = lib.mkOption {
      default = {};
      type = lib.types.attrsOf serviceSubmodule;
      description = "Host-local network services registered by feature modules for local reverse proxying and DNS synthesis.";
    };

    forwardAuth = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable local `forward_auth` SSO delegation for proxied services with `auth = \"sso\"`.";
      };
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "127.0.0.1:9091";
        description = "Upstream authentication server `host:port` passed to reverse-proxy `forward_auth`.";
      };
    };

    oidc = {
      available = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether a local OpenID Connect 1.0 identity provider module is imported on this host.";
      };
      requested = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether any local service on this host requests OpenID Connect authentication.";
      };
      issuerUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "https://auth.example.dev";
        description = "OpenID Connect 1.0 issuer URL (`https://<fqdn>`) advertised to relying parties on this host.";
      };
      systemdUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        apply = lib.unique;
        description = "Local systemd units (reverse proxy and identity provider) that OIDC relying parties order `after`/`wants`.";
      };
    };
  };
}
