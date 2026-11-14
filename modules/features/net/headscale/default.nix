/*
  feat/net/headscale

Configures a self-hosted Headscale coordination server behind Caddy with
automatic Split-DNS integration across `inventory.net.domains` and Authelia OIDC
authentication.

Exposes:

- flake.nixosModules."feat/net/headscale":
*/
{...} @ flake: let
  moduleName = "feat/net/headscale";
  port = 8085;
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
        description = "Select the unique domain in `inventory.net.domains` carrying this tag";
      };
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default =
          if selfCfg.domainTag != null
          then flake.config.inventory.net.lib.resolveTag selfCfg.domainTag
          else null;
        defaultText = lib.literalExpression ''
          if config.mod."feat/net/headscale".domainTag != null
          then inventory.net.lib.resolveTag config.mod."feat/net/headscale".domainTag
          else null
        '';
        description = "Base domain key in `inventory.net.domains` hosting Headscale (`<subdomain>.<domain>`) and MagicDNS (`tail.<domain>`)";
      };
      subdomain = lib.mkOption {
        type = lib.types.str;
        default = "vpn";
        description = "Subdomain label under `domain` where Tailscale clients reach Headscale";
      };
      adminUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["user@example.net"];
        description = "User email identifiers (`user@domain`) placed in `group:devs` for `tag:router` ownership and route auto-approval";
      };
      autoApproveRoutes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["192.168.86.0/24"];
        description = "Subnet CIDRs automatically approved in Headscale's ACL policy when advertised by `adminUsers` or `tag:router`";
      };
      enableOidc = lib.mkOption {
        type = lib.types.bool;
        default = config.mod.meta.has "feat/net/authelia";
        defaultText = lib.literalExpression ''config.mod.meta.has "feat/net/authelia"'';
        description = "Enable OpenID Connect node authentication via local Authelia";
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
    package = pkgs.headscale;
    flakeNet = flake.config.inventory.net;
    currentHost = config.networking.hostName;
    hostIpv4 = (flakeNet.hosts.${currentHost} or {}).ipv4 or null;
    tagMatches =
      if cfg.domainTag != null
      then flakeNet.lib.domainsWithTag cfg.domainTag
      else [];

    serverDomain =
      if cfg.domain != null
      then flakeNet.lib.qualifyKeyFor cfg.domain cfg.subdomain
      else null;
    magicDnsDomain =
      if cfg.domain != null
      then "tail.${cfg.domain}"
      else null;

    localAuthelia = config.mod.meta.has "feat/net/authelia";
    localCaddy = config.mod.meta.has "feat/net/caddy";
    autheliaCfg = config.mod."feat/net/authelia";
    oidcIssuerUrl =
      if localAuthelia && autheliaCfg.domain != null
      then "https://${flakeNet.lib.qualifyKeyFor autheliaCfg.domain autheliaCfg.subdomain}"
      else null;
    oidcSecretPath =
      if cfg.enableOidc
      then config.sops.secrets."services/headscale/oidc_client_secret".path
      else "";

    splitDnsDomains =
      flakeNet.domains
      |> lib.filterAttrs (_: dCfg: dCfg.splitDns)
      |> builtins.attrNames;

    policyFile = (pkgs.formats.json {}).generate "headscale-policy.json" (
      {
        acls = [
          {
            action = "accept";
            src = ["*"];
            dst = ["*:*"];
          }
        ];
      }
      // lib.optionalAttrs (cfg.adminUsers != []) {
        groups = {
          "group:devs" = cfg.adminUsers;
        };
        tagOwners = {
          "tag:router" = ["group:devs"];
        };
      }
      // lib.optionalAttrs (cfg.autoApproveRoutes != [] && cfg.adminUsers != []) {
        autoApprovers = {
          routes = lib.genAttrs cfg.autoApproveRoutes (_: [
            "group:devs"
            "tag:router"
          ]);
        };
      }
    );

    checkScript = pkgs.replaceVars ./check-config.sh {
      HEADSCALE_BIN = lib.getExe package;
      CONFIG_FILE = config.services.headscale.configFile;
      OIDC_SECRET_PATH = oidcSecretPath;
    };
  in {
    assertions = [
      {
        assertion = cfg.domain != null && flakeNet.domains ? ${cfg.domain};
        message =
          if cfg.domainTag != null && cfg.domain == null
          then
            if tagMatches == []
            then "mod.\"${moduleName}\": domainTag '${cfg.domainTag}' matched no domains in inventory.net.domains."
            else "mod.\"${moduleName}\": domainTag '${cfg.domainTag}' is ambiguous (matched: ${lib.concatStringsSep ", " tagMatches}); set `domain` explicitly."
          else "mod.\"${moduleName}\".domain ('${toString cfg.domain}') must reference a declared domain in inventory.net.domains.";
      }
      {
        assertion = serverDomain == null || serverDomain != magicDnsDomain;
        message = "mod.\"${moduleName}\": subdomain '${cfg.subdomain}' collides with MagicDNS domain 'tail'.";
      }
      {
        assertion =
          flakeNet.vpnUrl
          == null
          || serverDomain == null
          || lib.removeSuffix "/" flakeNet.vpnUrl == "https://${serverDomain}";
        message = "mod.\"${moduleName}\": server URL ('https://${toString serverDomain}') disagrees with inventory.net.vpnUrl ('${toString flakeNet.vpnUrl}').";
      }
      {
        assertion = cfg.autoApproveRoutes == [] || cfg.adminUsers != [];
        message = "mod.\"${moduleName}\": adminUsers (e.g. [\"user@example.com\"]) must be set when autoApproveRoutes is non-empty.";
      }
      {
        assertion = !cfg.enableOidc || oidcIssuerUrl != null;
        message = "mod.\"${moduleName}\".enableOidc requires `feat/net/authelia` with a configured domain on this host.";
      }
    ];

    mod = {
      meta.imported = [moduleName];
      # Allow authenticated tailnet nodes to pass Caddy's @not_lan CIDR guard for `access = "lan"` services
      "feat/net/caddy".lanCidrs = lib.mkIf localCaddy [
        ipv4Prefix
        ipv6Prefix
      ];
    };

    sops.secrets = lib.mkIf cfg.enableOidc {
      "services/headscale/oidc_client_secret" = {
        owner = config.services.headscale.user;
      };
    };

    services.headscale = {
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

    systemd.services.headscale = lib.mkIf (cfg.enableOidc && (localAuthelia || localCaddy)) {
      after =
        lib.optional localCaddy "caddy.service"
        ++ lib.optional localAuthelia "authelia-main.service";
      wants =
        lib.optional localCaddy "caddy.service"
        ++ lib.optional localAuthelia "authelia-main.service";
    };

    system.checks = lib.mkIf (serverDomain != null && magicDnsDomain != null) [
      (pkgs.runCommand "check-headscale-config" {} ''
        ${pkgs.runtimeShell} ${checkScript} "$out"
      '')
    ];
  };
}
