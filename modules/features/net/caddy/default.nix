/*
  feat/net/caddy

Enables Caddy web server and multi-domain reverse proxy driven by
`site.net.domains`, with per-domain internal/ACME TLS, client CIDR
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
      dnsAccount = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "default";
        description = "Account key in `site.net.dns` and `net/dns/<account>/` in `sops.secrets`";
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
      virtualHosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.either lib.types.str (lib.types.attrsOf lib.types.anything)
        );
        default = {};
        description = ''
          Declarative virtual hosts. Keys without a dot automatically get `.${flake.config.site.net.defaultDomain}` appended.
          Values can be either an upstream URL/address string (shorthand for `reverse_proxy <upstream>`)
          or a `services.caddy.virtualHosts` submodule attrset.
        '';
      };
      acme =
        acmeProviderOpts
        // {
          dnsAccount = lib.mkOption {
            type = lib.types.str;
            default = "default";
            example = "personal";
            description = "Default account key in `site.net.dns` and `net/dns/<account>/` in `sops.secrets`";
          };
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Issue wildcard ACME DNS-01 certificates via `security.acme` for every domain in `site.net.domains` with `tls = \"acme\"`";
          };
          email = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional contact email address for Let's Encrypt ACME account registration";
          };
          domains = lib.mkOption {
            default = {};
            type = lib.types.attrsOf (lib.types.submodule {options = acmeProviderOpts;});
            description = "Optional per-domain DNS-01 provider/credential overrides (keyed by domain name in `site.net.domains`)";
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
        description = "Whether to open HTTP/HTTPS ports to `mod.\"common/site/net\".trustedCidrs`";
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
    netCfg = config.mod."common/site/net";
    package = pkgs.caddy;
    flakeNet = flake.config.site.net;
    currentHost = config.networking.hostName;
    hostIpv4 = (flakeNet.hosts.${currentHost} or {}).ipv4 or null;
    endpoints = import ./_endpoints.nix {inherit lib;};

    managedAcmeDomains =
      flakeNet.domains
      |> lib.filterAttrs (_: dCfg: dCfg.tls == "acme")
      |> builtins.attrNames;

    resolveAcmeFor = d: let
      providerSecretSpecs = {
        porkbun = {
          PORKBUN_API_KEY_FILE = "api_key";
          PORKBUN_SECRET_API_KEY_FILE = "secret_key";
        };
      };
      ovr = cfg.acme.domains.${d} or {};
      domainAccount = (flakeNet.domains.${d} or {}).dnsAccount or null;
      dnsAccount =
        if (ovr.dnsAccount or null) != null
        then ovr.dnsAccount
        else if domainAccount != null
        then domainAccount
        else cfg.acme.dnsAccount;
      dnsProvider =
        if flakeNet.dns ? ${dnsAccount}
        then flakeNet.dns.${dnsAccount}.provider
        else null;
      environmentFile =
        if (ovr.environmentFile or null) != null
        then ovr.environmentFile
        else cfg.acme.environmentFile;
      explicitCreds =
        if (ovr.credentialFiles or {}) != {}
        then ovr.credentialFiles
        else cfg.acme.credentialFiles;
      spec =
        if dnsProvider != null && environmentFile == null && explicitCreds == {}
        then providerSecretSpecs.${dnsProvider} or null
        else null;
    in {
      inherit dnsAccount dnsProvider environmentFile;
      sopsSecretKeys =
        if spec != null
        then map (field: "net/dns/${dnsAccount}/${field}") (builtins.attrValues spec)
        else [];
      credentialFiles =
        if explicitCreds != {}
        then explicitCreds
        else if spec != null
        then builtins.mapAttrs (_: field: config.sops.secrets."net/dns/${dnsAccount}/${field}".path) spec
        else {};
    };

    vhosts = import ./_vhosts.nix {
      inherit
        cfg
        currentHost
        endpoints
        flakeNet
        lib
        managedAcmeDomains
        netCfg
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
      (import ./_firewall.nix {
        inherit
          cfg
          config
          endpoints
          httpPort
          httpsPort
          lib
          netCfg
          pkgs
          vhosts
          ;
      })
      {
        assertions = import ./_assertions.nix {
          inherit
            cfg
            currentHost
            endpoints
            flakeNet
            lib
            managedAcmeDomains
            moduleName
            netCfg
            resolveAcmeFor
            vhosts
            ;
        };

        mod = {
          meta.imported = [moduleName];
          "common/site/net" = {
            dnsRecords = lib.mkIf (hostIpv4 != null) (
              lib.mapAttrs' (
                key: _:
                  lib.nameValuePair (flakeNet.lib.extractHostname key) (lib.mkDefault hostIpv4)
              )
              vhosts.explicitDnsVHosts
            );
            oidc.systemdUnits = lib.mkIf netCfg.oidc.available ["caddy.service"];
          };
        };

        sops.secrets = lib.mkIf cfg.acme.enable (
          managedAcmeDomains
          |> lib.concatMap (d: (resolveAcmeFor d).sopsSecretKeys)
          |> lib.unique
          |> (keys: lib.genAttrs keys (_: {}))
        );

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
          # Managed via `_firewall.nix` so port 80 stays restricted to `trustedCidrs`
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
