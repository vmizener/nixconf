/*
  feat/net/headscale

Configures a self-hosted Headscale coordination server behind Caddy with
automatic Split-DNS integration across `site.net.domains` and Authelia OIDC
authentication.

Exposes:

- flake.nixosModules."feat/net/headscale":
*/
{...} @ flake: let
  moduleName = "feat/net/headscale";
  port = 8085;
  webUiPort = 3000;
  webUiCookieSecretPath = "/var/lib/headplane/cookie_secret";
  ipv4Prefix = "100.64.0.0/10";
  ipv6Prefix = "fd7a:115c:a1e0::/48";
in {
  flake.nixosModules."common/options" = {
    config,
    lib,
    ...
  }: let
    selfCfg = config.mod.${moduleName};
  in {
    options.mod.${moduleName} = {
      domainTag = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "vpn";
        description = "Select the unique domain in `site.net.domains` carrying this tag";
      };
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default =
          if selfCfg.domainTag != null
          then flake.config.site.net.lib.resolveTag selfCfg.domainTag
          else null;
        defaultText = lib.literalExpression ''
          if config.mod."feat/net/headscale".domainTag != null
          then site.net.lib.resolveTag config.mod."feat/net/headscale".domainTag
          else null
        '';
        description = "Base domain key in `site.net.domains` hosting Headscale (`<subdomain>.<domain>`) and MagicDNS (`tail.<domain>`)";
      };
      subdomain = lib.mkOption {
        type = lib.types.str;
        default = "vpn";
        description = "Subdomain label under `domain` where Tailscale clients reach Headscale";
      };
      adminUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = flake.config.site.net.adminEmails;
        defaultText = lib.literalExpression "site.net.adminEmails";
        example = ["user@example.net"];
        description = "User email identifiers (`user@domain`) placed in `group:devs` for `tag:router` ownership and route auto-approval";
      };
      autoApproveRoutes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["192.168.1.0/24"];
        description = "Subnet CIDRs automatically approved in Headscale's ACL policy when advertised by `adminUsers` or `tag:router`";
      };
      enableOidc = lib.mkOption {
        type = lib.types.bool;
        default = config.mod."common/site/net".oidc.available;
        defaultText = lib.literalExpression ''config.mod."common/site/net".oidc.available'';
        description = "Enable OpenID Connect node authentication via `mod.\"common/site/net\".oidc`";
      };
      oidcClientSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Runtime secret file containing Headscale's OIDC client secret when `enableOidc` is enabled (defaults to `config.sops.secrets.\"services/headscale/oidc_client_secret\".path`; for custom `sops.secrets.<key>`, use `\"\${config.sops.defaultSymlinkPath}/<key>\"`)";
      };
      webUi = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Headplane web UI for Headscale behind the local reverse proxy";
        };
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default =
            if selfCfg.domain != null
            then selfCfg.domain
            else flake.config.site.net.defaultDomain;
          defaultText = lib.literalExpression ''config.mod."feat/net/headscale".domain or site.net.defaultDomain'';
          description = "Target domain key in `site.net.domains` hosting the Headplane web UI";
        };
        subdomain = lib.mkOption {
          type = lib.types.str;
          default = "headplane";
          description = "Subdomain label under `webUi.domain` for the Headplane web UI";
        };
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
    package = pkgs.headscale;
    flakeNet = flake.config.site.net;
    currentHost = config.networking.hostName;
    hostIpv4 = (flakeNet.hosts.${currentHost} or {}).ipv4 or null;

    serverDomain =
      if cfg.domain != null
      then flakeNet.lib.qualifyKeyFor cfg.domain cfg.subdomain
      else null;
    magicDnsDomain =
      if cfg.domain != null
      then "tail.${cfg.domain}"
      else null;
    webUiFqdn =
      if cfg.webUi.domain != null
      then flakeNet.lib.qualifyKeyFor cfg.webUi.domain cfg.webUi.subdomain
      else null;

    oidcIssuerUrl = netCfg.oidc.issuerUrl;
    oidcSecretPath =
      if !cfg.enableOidc
      then ""
      else if cfg.oidcClientSecretFile != null
      then toString cfg.oidcClientSecretFile
      else config.sops.secrets."services/headscale/oidc_client_secret".path;

    splitDnsDomains =
      flakeNet.domains
      |> lib.filterAttrs (_: dCfg: dCfg.splitDns)
      |> builtins.attrNames;

    policyFile = import ./_policy.nix {
      inherit cfg lib pkgs;
    };

    checkScript = pkgs.replaceVars ./check-config.sh {
      HEADSCALE_BIN = lib.getExe package;
      CONFIG_FILE = config.services.headscale.configFile;
      OIDC_SECRET_PATH = oidcSecretPath;
    };

    ensureCookieSecretScript = pkgs.replaceVars ./ensure-cookie-secret.sh {
      COOKIE_SECRET_PATH = webUiCookieSecretPath;
      OPENSSL_BIN = lib.getExe pkgs.openssl;
    };
  in {
    assertions = import ./_assertions.nix {
      inherit
        cfg
        flakeNet
        lib
        magicDnsDomain
        moduleName
        oidcIssuerUrl
        serverDomain
        ;
    };

    mod = {
      meta.imported = [moduleName];
      "common/site/net" = {
        # Allow authenticated tailnet nodes to pass LAN CIDR guards for `access = "lan"` services
        trustedCidrs = [
          ipv4Prefix
          ipv6Prefix
        ];
        oidc.requested = lib.mkIf cfg.enableOidc true;
        services = lib.mkIf cfg.webUi.enable {
          headplane = {
            port = webUiPort;
            domain = cfg.webUi.domain;
            subdomain = cfg.webUi.subdomain;
            rootRedirect = "/admin";
            access = "lan";
            auth =
              if netCfg.forwardAuth.enable
              then "sso"
              else "none";
          };
        };
      };
    };

    sops.secrets = lib.mkIf (cfg.enableOidc && cfg.oidcClientSecretFile == null) {
      "services/headscale/oidc_client_secret" = {
        owner = lib.mkDefault config.services.headscale.user;
      };
    };

    services = {
      headscale = {
        enable = true;
        inherit package port;
        address = "127.0.0.1";
        settings =
          {
            server_url = "https://${toString serverDomain}";
            prefixes = {
              v4 = ipv4Prefix;
              v6 = ipv6Prefix;
            };
            dns = {
              magic_dns = true;
              base_domain = toString magicDnsDomain;
              override_local_dns = false;
              nameservers.split = lib.optionalAttrs (hostIpv4 != null) (
                lib.genAttrs splitDnsDomains (_: [hostIpv4])
              );
            };
            policy = {
              mode = "file";
              path = policyFile;
            };
          }
          // lib.optionalAttrs cfg.enableOidc {
            oidc = {
              only_start_if_oidc_is_available = false;
              issuer = toString oidcIssuerUrl;
              client_id = "headscale";
              client_secret_path = oidcSecretPath;
              scope = [
                "openid"
                "profile"
                "email"
                "groups"
              ];
              allowed_groups = ["devs"];
              pkce = {
                enabled = true;
                method = "S256";
              };
            };
          };
      };

      headplane = lib.mkIf cfg.webUi.enable {
        enable = true;
        settings = {
          server = {
            host = "127.0.0.1";
            port = webUiPort;
            base_url = lib.mkIf (webUiFqdn != null) "https://${webUiFqdn}";
            cookie_secret_path = webUiCookieSecretPath;
            cookie_secure = true;
            cookie_max_age = 30 * 24 * 3600;
          };
          headscale = {
            url = "http://127.0.0.1:${toString port}";
            public_url = "https://${toString serverDomain}";
            config_path = config.services.headscale.configFile;
          };
        };
      };
    };

    systemd.services = {
      headscale = lib.mkIf (cfg.enableOidc && netCfg.oidc.systemdUnits != []) {
        after = netCfg.oidc.systemdUnits;
        wants = netCfg.oidc.systemdUnits;
      };
      headplane = lib.mkIf cfg.webUi.enable {
        serviceConfig.ExecStartPre = ["${pkgs.runtimeShell} ${ensureCookieSecretScript}"];
      };
    };

    system.checks = lib.mkIf (serverDomain != null && magicDnsDomain != null) [
      (pkgs.runCommand "check-headscale-config" {} ''
        ${pkgs.runtimeShell} ${checkScript} "$out"
      '')
    ];
  };
}
