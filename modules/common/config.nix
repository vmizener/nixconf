/*
  common/config

Loads site-wide deployment settings from TOML configuration files
(`inputs.nixconf-config/config.toml`) into `inventory.{config,net}` and wires
shared NixOS module defaults without hardcoding hosts, users, or domains in Nix
modules.

Exposes:

- options.inventory.config
- flake.nixosModules."common/config"
*/
{
  config,
  inputs,
  lib,
  ...
}: let
  moduleName = "common/config";
  flakeCfg = config.inventory.config;
  flakeNet = config.inventory.net;
in {
  options.inventory.config = {
    files = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = "TOML files merged into `inventory.config` and `inventory.net` (use `lib.mkForce` to replace defaults).";
    };
    adminEmails = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Admin identities (`user@domain`) granted VPN route/tag ownership.";
    };
    dnsProvider = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default ACME DNS-01 provider name configured across proxy hosts.";
    };
  };

  config = let
    tomlConfigs = map lib.importTOML flakeCfg.files;

    allowedSections = ["net"];
    allowedNetKeys = [
      "admin_emails"
      "default_domain"
      "dns_provider"
      "domains"
      "proxy_host"
      "vpn_url"
    ];
    allowedDomainKeys = [
      "access"
      "default_auth"
      "publish_hosts"
      "split_dns"
      "tags"
      "tls"
    ];

    unknownSections =
      lib.unique (lib.concatMap builtins.attrNames tomlConfigs)
      |> builtins.filter (s: !(builtins.elem s allowedSections));
    unknownNetKeys =
      lib.unique (lib.concatMap (t: builtins.attrNames (t.net or {})) tomlConfigs)
      |> builtins.filter (k: !(builtins.elem k allowedNetKeys));
    unknownDomainKeys =
      lib.unique (
        lib.concatMap (
          t: lib.concatMap builtins.attrNames (builtins.attrValues (t.net.domains or {}))
        )
        tomlConfigs
      )
      |> builtins.filter (k: !(builtins.elem k allowedDomainKeys));

    tomlSchemaAssertions = [
      {
        assertion = unknownSections == [];
        message = "inventory.config.files: unexpected top-level section(s): ${lib.concatStringsSep ", " unknownSections} (allowed: ${lib.concatStringsSep ", " allowedSections})";
      }
      {
        assertion = unknownNetKeys == [];
        message = "inventory.config.files: unexpected [net] key(s): ${lib.concatStringsSep ", " unknownNetKeys} (allowed: ${lib.concatStringsSep ", " allowedNetKeys})";
      }
      {
        assertion = unknownDomainKeys == [];
        message = "inventory.config.files: unexpected [net.domains.*] key(s): ${lib.concatStringsSep ", " unknownDomainKeys} (allowed: ${lib.concatStringsSep ", " allowedDomainKeys})";
      }
    ];

    pickLast = attrPath:
      tomlConfigs
      |> builtins.filter (lib.hasAttrByPath attrPath)
      |> map (lib.getAttrFromPath attrPath)
      |> (vals:
        if vals == []
        then null
        else lib.last vals);

    mapDomainToml = d:
      lib.optionalAttrs (d ? tags) {inherit (d) tags;}
      // lib.optionalAttrs (d ? access) {inherit (d) access;}
      // lib.optionalAttrs (d ? tls) {inherit (d) tls;}
      // lib.optionalAttrs (d ? default_auth) {defaultAuth = d.default_auth;}
      // lib.optionalAttrs (d ? publish_hosts) {publishHosts = d.publish_hosts;}
      // lib.optionalAttrs (d ? split_dns) {splitDns = d.split_dns;};

    explicitProxyHost = pickLast ["net" "proxy_host"];
    explicitDefaultDomain = pickLast ["net" "default_domain"];
    explicitVpnUrl = pickLast ["net" "vpn_url"];
    explicitDnsProvider = pickLast ["net" "dns_provider"];
    vpnDomain = flakeNet.lib.resolveTag "vpn";
  in {
    inventory = {
      config = {
        files =
          lib.optional
          (builtins.pathExists "${inputs.nixconf-config}/config.toml")
          "${inputs.nixconf-config}/config.toml";
        adminEmails = lib.concatMap (t: t.net.admin_emails or []) tomlConfigs;
        dnsProvider = lib.mkIf (explicitDnsProvider != null) (lib.mkDefault explicitDnsProvider);
      };

      net = {
        defaultDomain = lib.mkIf (explicitDefaultDomain != null) (lib.mkDefault explicitDefaultDomain);
        proxyHost = lib.mkIf (explicitProxyHost != null) (lib.mkDefault explicitProxyHost);
        vpnUrl = lib.mkDefault (
          if explicitVpnUrl != null
          then explicitVpnUrl
          else if vpnDomain != null
          then "https://vpn.${vpnDomain}"
          else null
        );
        domains = lib.mkMerge (
          map (t: builtins.mapAttrs (_: mapDomainToml) (t.net.domains or {})) tomlConfigs
        );
      };
    };

    flake.nixosModules.${moduleName} = {
      config,
      lib,
      ...
    }: let
      hasCaddy = config.mod.meta.has "feat/net/caddy";
      caddyCfg = config.mod."feat/net/caddy";
      usePorkbunSecrets =
        hasCaddy
        && caddyCfg.acme.enable
        && caddyCfg.acme.dnsProvider == "porkbun";
    in {
      assertions = tomlSchemaAssertions;

      mod = {
        meta.imported = [moduleName];
        "feat/net/headscale".adminUsers =
          lib.mkIf (flakeCfg.adminEmails != []) (lib.mkDefault flakeCfg.adminEmails);
        "feat/net/caddy".acme = {
          dnsProvider =
            lib.mkIf (flakeCfg.dnsProvider != null) (lib.mkDefault flakeCfg.dnsProvider);
          credentialFiles = lib.mkIf usePorkbunSecrets {
            PORKBUN_API_KEY_FILE = lib.mkDefault config.sops.secrets."net/porkbun/0/api_key".path;
            PORKBUN_SECRET_API_KEY_FILE = lib.mkDefault config.sops.secrets."net/porkbun/0/secret_key".path;
          };
        };
      };

      sops.secrets = lib.mkIf usePorkbunSecrets {
        "net/porkbun/0/api_key" = {};
        "net/porkbun/0/secret_key" = {};
      };
    };
  };
}
