/*
  feat/net/caddy

Enables Caddy web server and multi-domain reverse proxy driven by
`inventory.net.domains`, with per-domain internal/ACME TLS, client CIDR
isolation, `forward_auth` SSO hooks, and kernel `nftables` sandboxing.

Exposes:

- flake.nixosModules."feat/net/caddy":
*/
{...} @ flake: let
  moduleName = "feat/net/caddy";
  httpPort = 80;
  httpsPort = 443;
in {
  flake.nixosModules."common/options" = {lib, ...}: let
    acmeProviderOpts = {
      dnsProvider = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "porkbun";
        description = "Lego DNS-01 provider name passed to `security.acme`";
      };
      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Runtime environment file containing DNS provider API credentials";
      };
      credentialFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = {};
        description = "Runtime secret files injected into `security.acme` via systemd `LoadCredential` (keys must end in `_FILE` or `_PATH`)";
      };
    };
  in {
    options.mod.${moduleName} = {
      lanCidrs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "127.0.0.0/8"
          "::1/128"
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "fd00::/8"
        ];
        description = "Trusted client CIDRs allowed to access `access = \"lan\"` virtual hosts and HTTP port 80";
      };
      virtualHosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.either lib.types.str (lib.types.attrsOf lib.types.anything)
        );
        default = {};
        description = ''
          Declarative virtual hosts. Keys without a dot automatically get `.${flake.config.inventory.net.defaultDomain}` appended.
          Values can be either an upstream URL/address string (shorthand for `reverse_proxy <upstream>`)
          or a `services.caddy.virtualHosts` submodule attrset.
        '';
      };
      acme =
        acmeProviderOpts
        // {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Issue wildcard ACME DNS-01 certificates via `security.acme` for every domain in `inventory.net.domains` with `tls = \"acme\"`";
          };
          email = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional contact email address for Let's Encrypt ACME account registration";
          };
          domains = lib.mkOption {
            default = {};
            type = lib.types.attrsOf (lib.types.submodule {options = acmeProviderOpts;});
            description = "Optional per-domain DNS-01 provider/credential overrides (keyed by domain name in `inventory.net.domains`)";
          };
        };
      forwardAuth = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Caddy `forward_auth` delegation for services with `auth = \"sso\"`";
        };
        address = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "127.0.0.1:9091";
          description = "Upstream authentication server `host:port` passed to Caddy `forward_auth`";
        };
      };
      egressSandbox = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Restrict outbound connections from `caddy.service` via kernel `nftables` UID filtering";
        };
        extraAllowedTargets = lib.mkOption {
          default = [];
          description = "Additional outbound IP/localhost endpoints `caddy.service` may connect to";
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                address = lib.mkOption {
                  type = lib.types.str;
                  example = "192.168.86.138";
                  description = "Destination IPv4/IPv6 literal or `127.0.0.1`/`localhost`";
                };
                port = lib.mkOption {
                  type = lib.types.port;
                  description = "Destination port";
                };
                proto = lib.mkOption {
                  type = lib.types.enum ["tcp" "udp"];
                  default = "tcp";
                  description = "Transport protocol";
                };
              };
            }
          );
        };
      };
      openLanFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open HTTP/HTTPS ports to `lanCidrs`";
      };
      openPublicFirewall = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to open HTTPS (443 TCP/UDP) globally; defaults to true when any public virtual host is configured";
      };
    };
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    package = pkgs.caddy;
    flakeNet = flake.config.inventory.net;
    currentHost = config.networking.hostName;
    hostIpv4 = (flakeNet.hosts.${currentHost} or {}).ipv4 or null;

    managedAcmeDomains =
      flakeNet.domains
      |> lib.filterAttrs (_: dCfg: dCfg.tls == "acme")
      |> builtins.attrNames;

    resolveAcmeFor = d: let
      ovr = cfg.acme.domains.${d} or {};
    in {
      dnsProvider =
        if (ovr.dnsProvider or null) != null
        then ovr.dnsProvider
        else cfg.acme.dnsProvider;
      environmentFile =
        if (ovr.environmentFile or null) != null
        then ovr.environmentFile
        else cfg.acme.environmentFile;
      credentialFiles =
        if (ovr.credentialFiles or {}) != {}
        then ovr.credentialFiles
        else cfg.acme.credentialFiles;
    };

    vhosts = import ./_vhosts.nix {
      inherit cfg currentHost flakeNet lib managedAcmeDomains;
    };
    firewallCfg = import ./_firewall.nix {
      inherit
        cfg
        config
        httpPort
        httpsPort
        lib
        pkgs
        vhosts
        ;
    };

    checkScript = pkgs.replaceVars ./check-config.sh {
      CADDY_BIN = lib.getExe package;
      CONFIG_FILE = config.services.caddy.configFile;
      LOG_DIR = config.services.caddy.logDir;
      MODE =
        if vhosts.usesRuntimeAcmeCerts
        then "adapt"
        else "validate";
    };
  in
    lib.mkMerge [
      firewallCfg
      {
        assertions = import ./_assertions.nix {
          inherit
            cfg
            currentHost
            flakeNet
            lib
            managedAcmeDomains
            moduleName
            resolveAcmeFor
            vhosts
            ;
        };

        mod = {
          meta.imported = [moduleName];
          "feat/net/blocky".customDNS = lib.mkIf (hostIpv4 != null) (
            lib.mapAttrs' (
              key: _:
                lib.nameValuePair (flakeNet.lib.extractHostname key) (lib.mkDefault hostIpv4)
            )
            vhosts.explicitDnsVHosts
          );
        };

        security.acme = lib.mkIf (cfg.acme.enable && managedAcmeDomains != []) {
          acceptTerms = true;
          defaults = lib.optionalAttrs (cfg.acme.email != null) {
            inherit (cfg.acme) email;
          };
          certs = lib.genAttrs managedAcmeDomains (d: let
            resolved = resolveAcmeFor d;
          in {
            domain = d;
            extraDomainNames = ["*.${d}"];
            inherit (resolved) credentialFiles dnsProvider environmentFile;
            group = config.services.caddy.group;
          });
        };

        services.caddy = {
          enable = true;
          inherit httpPort httpsPort package;
          # Managed via `_firewall.nix` so port 80 stays restricted to `lanCidrs`
          openFirewall = false;
          globalConfig = lib.optionalString vhosts.hasHttpsVHosts ''
            servers :${toString httpsPort} {
              strict_sni_host
            }
          '';
          virtualHosts = vhosts.allVHosts;
        };

        system.checks = [
          (pkgs.runCommand "check-caddy-config" {} ''
            ${pkgs.runtimeShell} ${checkScript} "$out"
          '')
        ];
      }
    ];
}
