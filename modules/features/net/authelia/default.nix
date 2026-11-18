/*
  feat/net/authelia

Configures Authelia SSO (`forward_auth`) for Caddy virtual hosts and an OpenID
Connect (OIDC) identity provider restricting Headscale VPN enrollment to
members of the `devs` group.

Exposes:

- flake.nixosModules."feat/net/authelia":
*/
{...} @ flake: let
  moduleName = "feat/net/authelia";
  port = 9091;
  stateDir = "/var/lib/authelia-main";
  credsDir = "/run/credentials/authelia-main.service";
in {
  flake.nixosModules."common/options" = {
    config,
    lib,
    ...
  }: let
    selfCfg = config.mod.${moduleName};
    mkSecretFileOption = secretKey: summary:
      lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "${summary} (defaults to `config.sops.secrets.\"${secretKey}\".path`; for custom `sops.secrets.<key>`, use `\"\${config.sops.defaultSymlinkPath}/<key>\"`)";
      };
  in {
    options.mod.${moduleName} = {
      domainTag = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "sso";
        description = "Select the unique domain in `site.net.domains` carrying this tag";
      };
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default =
          if selfCfg.domainTag != null
          then flake.config.site.net.lib.resolveTag selfCfg.domainTag
          else null;
        defaultText = lib.literalExpression ''
          if config.mod."feat/net/authelia".domainTag != null
          then site.net.lib.resolveTag config.mod."feat/net/authelia".domainTag
          else null
        '';
        description = "Target domain key in `site.net.domains` hosting the Authelia portal and session cookie scope";
      };
      subdomain = lib.mkOption {
        type = lib.types.str;
        default = "auth";
        description = "Subdomain label under `domain` for the Authelia portal";
      };
      enableOidc = lib.mkOption {
        type = lib.types.bool;
        default = config.mod."common/site/net".oidc.requested;
        defaultText = lib.literalExpression ''config.mod."common/site/net".oidc.requested'';
        description = "Enable Authelia's OpenID Connect 1.0 provider (`group:devs`)";
      };
      jwtSecretFile =
        mkSecretFileOption "services/authelia/jwt_secret"
        "Runtime secret file for Authelia identity validation JWT signing";
      storageEncryptionKeyFile =
        mkSecretFileOption "services/authelia/storage_encryption_key"
        "Runtime secret file for Authelia SQLite storage encryption";
      sessionSecretFile =
        mkSecretFileOption "services/authelia/session_secret"
        "Runtime secret file for Authelia session cookie encryption";
      usersFile =
        mkSecretFileOption "services/authelia/users_yml"
        "Runtime YAML user database file loaded into Authelia";
      oidcHmacSecretFile =
        mkSecretFileOption "services/authelia/oidc_hmac_secret"
        "Runtime secret file for Authelia OIDC HMAC signing when `enableOidc` is enabled";
      oidcIssuerPrivateKeyFile =
        mkSecretFileOption "services/authelia/oidc_issuer_key"
        "Runtime PEM private key file for Authelia OIDC token signing when `enableOidc` is enabled";
      headscaleClientSecretHashFile =
        mkSecretFileOption "services/authelia/headscale_client_secret_hash"
        "Runtime file containing the hashed OIDC client secret for Headscale when `enableOidc` is enabled";
    };
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    package = pkgs.authelia;
    secretPathOr = optVal: secretKey:
      if optVal != null
      then optVal
      else config.sops.secrets.${secretKey}.path;
    flakeNet = flake.config.site.net;
    tagMatches =
      if cfg.domainTag != null
      then flakeNet.lib.domainsWithTag cfg.domainTag
      else [];
    cookieDomain =
      if cfg.domain != null
      then cfg.domain
      else flakeNet.defaultDomain;
    authFqdn = flakeNet.lib.qualifyKeyFor cookieDomain cfg.subdomain;
    headscaleRedirectUri =
      if flakeNet.vpnUrl != null
      then "${lib.removeSuffix "/" flakeNet.vpnUrl}/oidc/callback"
      else null;

    # Enable Authelia `forward_auth` cookies across `cookieDomain` plus every
    # multi-label domain in `site.net.domains` (individual services still
    # opt in/out via `auth = "sso" | "none"`).
    ssoDomains =
      (
        flakeNet.domains
        |> lib.filterAttrs (
          d: dCfg:
            lib.hasInfix "." d
            && (dCfg.tls == "acme" || dCfg.defaultAuth == "sso" || builtins.elem "sso" dCfg.tags)
        )
        |> builtins.attrNames
      )
      ++ [cookieDomain]
      |> lib.unique;

    authFqdnFor = d: flakeNet.lib.qualifyKeyFor d cfg.subdomain;

    declaredInventoryFqdns =
      lib.concatMap (
        h:
          builtins.attrValues h.services
          |> map (svc: flakeNet.lib.extractHostname (flakeNet.lib.qualifyService svc))
      )
      (builtins.attrValues flakeNet.hosts);

    publicSsoInventoryDomains =
      lib.concatMap (
        h:
          builtins.attrValues h.services
          |> builtins.filter (svc: svc.access == "public" && svc.auth == "sso" && svc.domain != null)
          |> map (svc: svc.domain)
      )
      (builtins.attrValues flakeNet.hosts);

    autoAuthDomains =
      ssoDomains
      |> builtins.filter (
        d:
          flakeNet.domains ? ${d}
          && !(builtins.elem (authFqdnFor d) declaredInventoryFqdns)
      );

    autheliaSettings =
      {
        theme = "auto";
        default_2fa_method = "webauthn";
        server = {
          address = "tcp://127.0.0.1:${toString port}/";
          endpoints.authz.forward-auth.implementation = "ForwardAuth";
        };
        log = {
          level = "info";
          format = "text";
        };
        totp = {
          disable = false;
          issuer = cookieDomain;
        };
        webauthn = {
          disable = false;
          enable_passkey_login = true;
          display_name = "${cookieDomain} SSO";
        };
        authentication_backend = {
          password_reset.disable = true;
          file = {
            path = "${credsDir}/users.yml";
            watch = false;
          };
        };
        regulation = {
          max_retries = 5;
          find_time = "2m";
          ban_time = "5m";
        };
        storage.local.path = "${stateDir}/db.sqlite3";
        notifier = {
          disable_startup_check = false;
          filesystem.filename = "${stateDir}/notification.txt";
        };
        session.cookies =
          map (d: {
            name = "authelia_session";
            domain = d;
            authelia_url = "https://${authFqdnFor d}";
            expiration = "1h";
            inactivity = "5m";
            remember_me = "1M";
          })
          ssoDomains;
        access_control = {
          default_policy = "deny";
          rules =
            map (d: {
              domain = [
                d
                "*.${d}"
              ];
              policy = "two_factor";
            })
            ssoDomains;
        };
      }
      // lib.optionalAttrs cfg.enableOidc {
        identity_providers.oidc = {
          authorization_policies.devs_only = {
            default_policy = "deny";
            rules = [
              {
                policy = "two_factor";
                subject = "group:devs";
              }
            ];
          };
          clients = [
            {
              client_id = "headscale";
              client_name = "Headscale";
              client_secret = "{{ mustEnv \"CREDENTIALS_DIRECTORY\" | printf \"%s/headscaleClientSecretHash\" | secret }}";
              public = false;
              authorization_policy = "devs_only";
              require_pkce = true;
              pkce_challenge_method = "S256";
              token_endpoint_auth_method = "client_secret_basic";
              redirect_uris = lib.optional (headscaleRedirectUri != null) headscaleRedirectUri;
              scopes = [
                "openid"
                "profile"
                "email"
                "groups"
              ];
              response_types = ["code"];
              grant_types = ["authorization_code"];
              access_token_signed_response_alg = "none";
              userinfo_signed_response_alg = "none";
            }
          ];
        };
      };

    yamlFormat = pkgs.formats.yaml {};
    generatedConfigFile = yamlFormat.generate "authelia-check-config.yml" autheliaSettings;
    oidcJwksTemplate = pkgs.writeText "oidc-jwks.yaml" ''
      identity_providers:
        oidc:
          jwks:
            - key: {{ mustEnv "CREDENTIALS_DIRECTORY" | printf "%s/oidcIssuerPrivateKeyFile" | secret | mindent 10 "|" | msquote }}
    '';

    checkScript = pkgs.replaceVars ./check-config.sh {
      AUTHELIA_BIN = lib.getExe package;
      OPENSSL_BIN = lib.getExe pkgs.openssl;
      CONFIG_FILE = generatedConfigFile;
      OIDC_JWKS_FILE = oidcJwksTemplate;
      COOKIE_DOMAIN = cookieDomain;
      CREDS_DIR = credsDir;
      STATE_DIR = stateDir;
      ENABLE_OIDC = lib.boolToString cfg.enableOidc;
    };
  in {
    assertions = import ./_assertions.nix {
      inherit
        cfg
        flakeNet
        headscaleRedirectUri
        lib
        moduleName
        tagMatches
        ;
    };

    mod = {
      meta.imported = [moduleName];
      "common/site/net" = {
        forwardAuth = {
          enable = lib.mkDefault true;
          address = lib.mkDefault "127.0.0.1:${toString port}";
        };
        oidc = {
          available = lib.mkDefault true;
          issuerUrl = lib.mkIf (cfg.enableOidc && cfg.domain != null) (
            lib.mkDefault "https://${authFqdn}"
          );
          systemdUnits = lib.mkIf cfg.enableOidc ["authelia-main.service"];
        };
        services = builtins.listToAttrs (
          map (
            d:
              lib.nameValuePair "auth-${d}" (
                {
                  inherit port;
                  domain = d;
                  inherit (cfg) subdomain;
                  auth = "none";
                }
                // lib.optionalAttrs (builtins.elem d publicSsoInventoryDomains) {
                  access = "public";
                }
              )
          )
          autoAuthDomains
        );
      };
    };

    sops.secrets =
      lib.optionalAttrs (cfg.jwtSecretFile == null) {
        "services/authelia/jwt_secret" = {};
      }
      // lib.optionalAttrs (cfg.storageEncryptionKeyFile == null) {
        "services/authelia/storage_encryption_key" = {};
      }
      // lib.optionalAttrs (cfg.sessionSecretFile == null) {
        "services/authelia/session_secret" = {};
      }
      // lib.optionalAttrs (cfg.usersFile == null) {
        "services/authelia/users_yml" = {};
      }
      // lib.optionalAttrs (cfg.enableOidc && cfg.oidcHmacSecretFile == null) {
        "services/authelia/oidc_hmac_secret" = {};
      }
      // lib.optionalAttrs (cfg.enableOidc && cfg.oidcIssuerPrivateKeyFile == null) {
        "services/authelia/oidc_issuer_key" = {};
      }
      // lib.optionalAttrs (cfg.enableOidc && cfg.headscaleClientSecretHashFile == null) {
        "services/authelia/headscale_client_secret_hash" = {};
      };

    # Ensure local daemons (e.g. Headscale OIDC discovery) resolve auth.<domain>
    # via loopback Caddy even before public DNS or the external relay is live.
    networking.hosts."127.0.0.1" = lib.mkIf (cfg.domain != null) (
      map authFqdnFor (builtins.filter (d: lib.hasInfix "." d) ssoDomains)
    );

    services.authelia.instances.main = {
      enable = true;
      inherit package;
      secrets = {
        jwtSecretFile = secretPathOr cfg.jwtSecretFile "services/authelia/jwt_secret";
        storageEncryptionKeyFile = secretPathOr cfg.storageEncryptionKeyFile "services/authelia/storage_encryption_key";
        sessionSecretFile = secretPathOr cfg.sessionSecretFile "services/authelia/session_secret";
        oidcHmacSecretFile =
          if cfg.enableOidc
          then secretPathOr cfg.oidcHmacSecretFile "services/authelia/oidc_hmac_secret"
          else null;
        oidcIssuerPrivateKeyFile =
          if cfg.enableOidc
          then secretPathOr cfg.oidcIssuerPrivateKeyFile "services/authelia/oidc_issuer_key"
          else null;
      };
      settings = autheliaSettings;
    };

    systemd.services.authelia-main = {
      environment.X_AUTHELIA_CONFIG_FILTERS = lib.mkIf cfg.enableOidc "template";
      serviceConfig.LoadCredential =
        ["users.yml:${toString (secretPathOr cfg.usersFile "services/authelia/users_yml")}"]
        ++ lib.optional cfg.enableOidc "headscaleClientSecretHash:${toString (secretPathOr cfg.headscaleClientSecretHashFile "services/authelia/headscale_client_secret_hash")}";
    };

    system.checks = lib.mkIf (cfg.domain != null) [
      (pkgs.runCommand "check-authelia-config" {} ''
        ${pkgs.runtimeShell} ${checkScript} "$out"
      '')
    ];
  };
}
