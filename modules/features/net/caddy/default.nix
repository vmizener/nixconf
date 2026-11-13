/*
  feat/net/caddy

Enables Caddy web server and dual-horizon (`lan` + `public`) reverse proxy with
per-vhost internal/ACME TLS, client CIDR isolation, `forward_auth` SSO hooks,
and kernel `nftables` ingress/egress sandboxing.

Exposes:

- flake.nixosModules."feat/net/caddy":
*/
{...} @ flake: let
  moduleName = "feat/net/caddy";
in {
  flake.nixosModules."common/options" = {
    lib,
    pkgs,
    ...
  }: {
    options.mod.${moduleName} = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.caddy;
        defaultText = lib.literalExpression "pkgs.caddy";
        description = "Caddy package to use";
      };
      httpPort = lib.mkOption {
        type = lib.types.port;
        default = 80;
        description = "HTTP listen port (restricted to `lanCidrs` in the firewall)";
      };
      httpsPort = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "HTTPS listen port";
      };
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
        description = "Trusted client CIDRs allowed to access LAN virtual hosts and HTTP port 80";
      };
      virtualHosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.either lib.types.str (lib.types.attrsOf lib.types.anything)
        );
        default = {};
        description = ''
          Declarative virtual hosts. Keys without a dot automatically get `.${flake.config.inventory.net.domain}` appended.
          Values can be either an upstream URL/address string (shorthand for `reverse_proxy <upstream>`)
          or a `services.caddy.virtualHosts` submodule attrset.
        '';
      };
      acme = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Issue a wildcard ACME DNS-01 certificate for `inventory.net.publicDomain` via `security.acme`";
        };
        email = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Contact email address for Let's Encrypt ACME account registration";
        };
        dnsProvider = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "cloudflare";
          description = "Lego DNS-01 provider name passed to `security.acme`";
        };
        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Runtime secret file containing DNS provider API credentials (e.g. `sops.secrets.<name>.path`)";
        };
        dnsPropagationCheck = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Wait for authoritative DNS TXT propagation before completing DNS-01 challenges";
        };
        staging = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use Let's Encrypt's staging directory for testing ACME issuance without hitting rate limits";
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
        uri = lib.mkOption {
          type = lib.types.str;
          default = "/api/authz/forward-auth";
          description = "Verification endpoint path queried on the `forward_auth` upstream";
        };
        copyHeaders = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "Remote-User"
            "Remote-Groups"
            "Remote-Email"
            "Remote-Name"
          ];
          description = "Identity headers copied from the `forward_auth` response to upstream services";
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
      enableConfigCheck = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Validate the generated Caddy configuration at build time";
      };
      openLanFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open `httpPort` (and `httpsPort` when `openPublicFirewall` is inactive) to `lanCidrs`";
      };
      openPublicFirewall = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to open `httpsPort` (TCP/UDP) globally; defaults to true when any public virtual host is configured";
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
    flakeNet = flake.config.inventory.net;
    currentHost = config.networking.hostName;
    hostIpv4 = (flakeNet.hosts.${currentHost} or {}).ipv4 or null;
    publicDomain = flakeNet.publicDomain;

    vhosts = import ./_vhosts.nix {
      inherit cfg currentHost flakeNet lib;
    };
    firewallCfg = import ./_firewall.nix {
      inherit cfg config lib pkgs vhosts;
    };
  in
    lib.mkMerge [
      firewallCfg
      {
        assertions = import ./_assertions.nix {
          inherit cfg currentHost flakeNet lib moduleName vhosts;
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

        security.acme = lib.mkIf (cfg.acme.enable && publicDomain != null) {
          acceptTerms = true;
          defaults =
            {
              inherit (cfg.acme) email;
            }
            // lib.optionalAttrs cfg.acme.staging {
              server = "https://acme-staging-v02.api.letsencrypt.org/directory";
            };
          certs.${publicDomain} = {
            domain = publicDomain;
            extraDomainNames = ["*.${publicDomain}"];
            inherit (cfg.acme) dnsPropagationCheck dnsProvider environmentFile;
            group = config.services.caddy.group;
          };
        };

        services.caddy = {
          enable = true;
          inherit (cfg) httpPort httpsPort package;
          # Managed via `_firewall.nix` so port 80 stays restricted to `lanCidrs`
          openFirewall = false;
          globalConfig = lib.optionalString vhosts.hasHttpsVHosts ''
            servers :${toString cfg.httpsPort} {
              strict_sni_host
            }
          '';
          virtualHosts = vhosts.allVHosts;
        };

        system.checks = lib.mkIf cfg.enableConfigCheck [
          (pkgs.runCommand "check-caddy-config" {} ''
            export XDG_DATA_HOME="$TMPDIR/data"
            export XDG_CONFIG_HOME="$TMPDIR/config"
            mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$TMPDIR/log"
            substitute ${config.services.caddy.configFile} "$TMPDIR/Caddyfile" \
              --replace-quiet "${config.services.caddy.logDir}" "$TMPDIR/log"
            ${
              if vhosts.usesRuntimeAcmeCerts
              then "${lib.getExe cfg.package} adapt --adapter caddyfile --config \"$TMPDIR/Caddyfile\" > /dev/null"
              else "${lib.getExe cfg.package} validate --adapter caddyfile --config \"$TMPDIR/Caddyfile\""
            }
            touch $out
          '')
        ];
      }
    ];
}
