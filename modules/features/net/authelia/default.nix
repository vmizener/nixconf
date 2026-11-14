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
  in {
    options.mod.${moduleName} = {
      domainTag = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "sso";
        description = "Select the unique domain in `inventory.net.domains` carrying this tag";
      };
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default =
          if selfCfg.domainTag != null
          then flake.config.inventory.net.lib.resolveTag selfCfg.domainTag
          else null;
        defaultText = lib.literalExpression ''
          if config.mod."feat/net/authelia".domainTag != null
          then inventory.net.lib.resolveTag config.mod."feat/net/authelia".domainTag
          else null
        '';
        description = "Target domain key in `inventory.net.domains` hosting the Authelia portal and session cookie scope";
      };
      subdomain = lib.mkOption {
        type = lib.types.str;
        default = "auth";
        description = "Subdomain label under `domain` for the Authelia portal";
      };
      enableOidc = lib.mkOption {
        type = lib.types.bool;
        default = config.mod.meta.has "feat/net/headscale";
        defaultText = lib.literalExpression ''config.mod.meta.has "feat/net/headscale"'';
        description = "Enable Authelia's OpenID Connect 1.0 provider for Headscale (`group:devs`)";
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
    package = pkgs.authelia;
    flakeNet = flake.config.inventory.net;
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

    # Protect `cookieDomain` plus any domains tagged `"sso"` or using `defaultAuth = "sso"`
    ssoDomains =
      (
        flakeNet.domains
        |> lib.filterAttrs (
          _: dCfg: dCfg.defaultAuth == "sso" || builtins.elem "sso" dCfg.tags
        )
        |> builtins.attrNames
      )
      ++ [cookieDomain]
      |> lib.unique;

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
        session.cookies = [
          {
            name = "authelia_session";
            domain = cookieDomain;
            authelia_url = "https://${authFqdn}";
            expiration = "1h";
            inactivity = "5m";
            remember_me = "1M";
          }
        ];
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
        assertion = !cfg.enableOidc || headscaleRedirectUri != null;
        message = "mod.\"${moduleName}\".enableOidc requires inventory.net.vpnUrl to be set for Headscale's callback URI.";
      }
    ];

    mod = {
      meta.imported = [moduleName];
      "feat/net/caddy".forwardAuth = lib.mkIf (config.mod.meta.has "feat/net/caddy") {
        enable = lib.mkDefault true;
        address = lib.mkDefault "127.0.0.1:${toString port}";
      };
    };

    sops.secrets =
      {
        "services/authelia/jwt_secret" = {};
        "services/authelia/storage_encryption_key" = {};
        "services/authelia/session_secret" = {};
        "services/authelia/users_yml" = {};
      }
      // lib.optionalAttrs cfg.enableOidc {
        "services/authelia/oidc_hmac_secret" = {};
        "services/authelia/oidc_issuer_key" = {};
        "services/authelia/headscale_client_secret_hash" = {};
      };

    # Ensure local daemons (e.g. Headscale OIDC discovery) resolve auth.<domain>
    # via loopback Caddy even before public DNS or the external relay is live.
    networking.hosts."127.0.0.1" = lib.mkIf (cfg.domain != null) [authFqdn];

    services.authelia.instances.main = {
      enable = true;
      inherit package;
      secrets = {
        jwtSecretFile = config.sops.secrets."services/authelia/jwt_secret".path;
        storageEncryptionKeyFile = config.sops.secrets."services/authelia/storage_encryption_key".path;
        sessionSecretFile = config.sops.secrets."services/authelia/session_secret".path;
        oidcHmacSecretFile =
          if cfg.enableOidc
          then config.sops.secrets."services/authelia/oidc_hmac_secret".path
          else null;
        oidcIssuerPrivateKeyFile =
          if cfg.enableOidc
          then config.sops.secrets."services/authelia/oidc_issuer_key".path
          else null;
      };
      settings = autheliaSettings;
    };

    systemd.services.authelia-main = {
      environment.X_AUTHELIA_CONFIG_FILTERS = lib.mkIf cfg.enableOidc "template";
      serviceConfig.LoadCredential =
        ["users.yml:${config.sops.secrets."services/authelia/users_yml".path}"]
        ++ lib.optional cfg.enableOidc "headscaleClientSecretHash:${config.sops.secrets."services/authelia/headscale_client_secret_hash".path}";
    };

    system.checks = lib.mkIf (cfg.domain != null) [
      (pkgs.runCommand "check-authelia-config" {} ''
        ${pkgs.runtimeShell} ${checkScript} "$out"
      '')
    ];
  };
}
