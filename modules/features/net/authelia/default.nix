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
      port = lib.mkOption {
        type = lib.types.port;
        default = 9091;
        description = "Local loopback TCP port Authelia listens on";
      };
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
    flakeNet = flake.config.site.net;
    secretPathOr = optVal: secretKey:
      if optVal != null
      then optVal
      else config.sops.secrets.${secretKey}.path;

    authelia = import ./_settings.nix {
      inherit
        cfg
        credsDir
        flakeNet
        lib
        stateDir
        ;
    };

    checkScript = pkgs.replaceVars ./check-config.sh {
      AUTHELIA_BIN = lib.getExe package;
      OPENSSL_BIN = lib.getExe pkgs.openssl;
      CONFIG_FILE = (pkgs.formats.yaml {}).generate "authelia-check-config.yml" authelia.settings;
      OIDC_JWKS_FILE = ./oidc-jwks.yaml;
      COOKIE_DOMAIN = authelia.cookieDomain;
      CREDS_DIR = credsDir;
      STATE_DIR = stateDir;
      ENABLE_OIDC = lib.boolToString cfg.enableOidc;
    };
  in {
    assertions = import ./_assertions.nix {
      inherit cfg flakeNet lib moduleName;
      inherit (authelia) headscaleRedirectUri;
    };

    mod = {
      meta.imported = [moduleName];
      "common/site/net" = {
        ports.authelia.tcp = [cfg.port];
        forwardAuth = {
          enable = lib.mkDefault true;
          address = lib.mkDefault "127.0.0.1:${toString cfg.port}";
        };
        oidc = {
          available = lib.mkDefault true;
          issuerUrl = lib.mkIf (cfg.enableOidc && cfg.domain != null) (
            lib.mkDefault "https://${authelia.authFqdn}"
          );
          systemdUnits = lib.mkIf cfg.enableOidc ["authelia-main.service"];
        };
        services = builtins.listToAttrs (
          map (
            d:
              lib.nameValuePair "auth-${d}" (
                {
                  backend = "authelia";
                  inherit (cfg) port subdomain;
                  domain = d;
                  auth = "none";
                }
                // lib.optionalAttrs (builtins.elem d authelia.publicSsoInventoryDomains) {
                  access = "public";
                }
              )
          )
          authelia.autoAuthDomains
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
      map authelia.authFqdnFor (builtins.filter (d: lib.hasInfix "." d) authelia.ssoDomains)
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
      inherit (authelia) settings;
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
