/*
  common/config

Loads site-wide deployment settings from TOML configuration files
(`inventory.siteConfig.configFiles`) into `inventory.net` and validates their
schema without hardcoding hosts, users, or domains in Nix modules.

Exposes:

- options.inventory.siteConfig
- flake.nixosModules."common/config"
*/
{
  config,
  lib,
  self,
  ...
}: let
  moduleName = "common/config";
  siteCfg = config.inventory.siteConfig;
  flakeNet = config.inventory.net;
in {
  options.inventory.siteConfig = {
    path = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = self;
      defaultText = lib.literalExpression "self";
      description = "Base directory or flake input containing default site files (`config.toml`, `keys.toml`, `secrets.yaml`).";
    };
    configFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = let
        defaultFile = "${siteCfg.path}/config.toml";
      in
        lib.optional
        (siteCfg.path != null && builtins.pathExists defaultFile)
        defaultFile;
      defaultText = lib.literalExpression ''
        lib.optional
          (config.inventory.siteConfig.path != null && builtins.pathExists "''${config.inventory.siteConfig.path}/config.toml")
          "''${config.inventory.siteConfig.path}/config.toml"
      '';
      description = "TOML files merged into `inventory.net`.";
    };
    keysFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = let
        defaultFile = "${siteCfg.path}/keys.toml";
      in
        lib.optional
        (siteCfg.path != null && builtins.pathExists defaultFile)
        defaultFile;
      defaultText = lib.literalExpression ''
        lib.optional
          (config.inventory.siteConfig.path != null && builtins.pathExists "''${config.inventory.siteConfig.path}/keys.toml")
          "''${config.inventory.siteConfig.path}/keys.toml"
      '';
      description = "TOML files merged into `inventory.ssh.{keys,authorize}`.";
    };
    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default =
        if siteCfg.path != null
        then "${siteCfg.path}/secrets.yaml"
        else null;
      defaultText = lib.literalExpression ''
        if config.inventory.siteConfig.path != null
        then "''${config.inventory.siteConfig.path}/secrets.yaml"
        else null
      '';
      description = "Default `sops-nix` secrets file wired to `sops.defaultSopsFile`.";
    };
  };

  config = let
    tomlConfigs = map lib.importTOML siteCfg.configFiles;

    allowedSections = ["net"];
    allowedNetKeys = [
      "admin_emails"
      "default_domain"
      "dns"
      "domains"
      "proxy_host"
      "vpn_url"
    ];
    allowedDnsKeys = [
      "provider"
    ];
    allowedDomainKeys = [
      "access"
      "default_auth"
      "dns_account"
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
    unknownDnsKeys =
      lib.unique (
        lib.concatMap (
          t: lib.concatMap builtins.attrNames (builtins.attrValues (t.net.dns or {}))
        )
        tomlConfigs
      )
      |> builtins.filter (k: !(builtins.elem k allowedDnsKeys));
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
        message = "inventory.siteConfig.configFiles: unexpected top-level section(s): ${lib.concatStringsSep ", " unknownSections} (allowed: ${lib.concatStringsSep ", " allowedSections})";
      }
      {
        assertion = unknownNetKeys == [];
        message = "inventory.siteConfig.configFiles: unexpected [net] key(s): ${lib.concatStringsSep ", " unknownNetKeys} (allowed: ${lib.concatStringsSep ", " allowedNetKeys})";
      }
      {
        assertion = unknownDnsKeys == [];
        message = "inventory.siteConfig.configFiles: unexpected [net.dns.*] key(s): ${lib.concatStringsSep ", " unknownDnsKeys} (allowed: ${lib.concatStringsSep ", " allowedDnsKeys})";
      }
      {
        assertion = unknownDomainKeys == [];
        message = "inventory.siteConfig.configFiles: unexpected [net.domains.*] key(s): ${lib.concatStringsSep ", " unknownDomainKeys} (allowed: ${lib.concatStringsSep ", " allowedDomainKeys})";
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

    mapDnsToml = d:
      lib.optionalAttrs (d ? provider) {inherit (d) provider;};

    mapDomainToml = d:
      lib.optionalAttrs (d ? tags) {inherit (d) tags;}
      // lib.optionalAttrs (d ? access) {inherit (d) access;}
      // lib.optionalAttrs (d ? tls) {inherit (d) tls;}
      // lib.optionalAttrs (d ? dns_account) {dnsAccount = d.dns_account;}
      // lib.optionalAttrs (d ? default_auth) {defaultAuth = d.default_auth;}
      // lib.optionalAttrs (d ? publish_hosts) {publishHosts = d.publish_hosts;}
      // lib.optionalAttrs (d ? split_dns) {splitDns = d.split_dns;};

    explicitProxyHost = pickLast ["net" "proxy_host"];
    explicitDefaultDomain = pickLast ["net" "default_domain"];
    explicitVpnUrl = pickLast ["net" "vpn_url"];
    vpnDomain = flakeNet.lib.resolveTag "vpn";
  in {
    inventory.net = {
      adminEmails = lib.concatMap (t: t.net.admin_emails or []) tomlConfigs;
      defaultDomain = lib.mkIf (explicitDefaultDomain != null) (lib.mkDefault explicitDefaultDomain);
      proxyHost = lib.mkIf (explicitProxyHost != null) (lib.mkDefault explicitProxyHost);
      vpnUrl = lib.mkDefault (
        if explicitVpnUrl != null
        then explicitVpnUrl
        else if vpnDomain != null
        then "https://vpn.${vpnDomain}"
        else null
      );
      dns = lib.mkMerge (
        map (t: builtins.mapAttrs (_: mapDnsToml) (t.net.dns or {})) tomlConfigs
      );
      domains = lib.mkMerge (
        map (t: builtins.mapAttrs (_: mapDomainToml) (t.net.domains or {})) tomlConfigs
      );
    };

    flake.nixosModules.${moduleName} = {...}: {
      assertions = tomlSchemaAssertions;
      mod.meta.imported = [moduleName];
    };
  };
}
