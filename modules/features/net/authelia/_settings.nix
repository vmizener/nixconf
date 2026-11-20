# Domain/cookie topology and Authelia instance settings synthesis for `feat/net/authelia`.
{
  cfg,
  credsDir,
  flakeNet,
  lib,
  stateDir,
}: let
  cookieDomain =
    if cfg.domain != null
    then cfg.domain
    else flakeNet.defaultDomain;

  authFqdn = flakeNet.lib.qualifyKeyFor cookieDomain cfg.subdomain;
  authFqdnFor = d: flakeNet.lib.qualifyKeyFor d cfg.subdomain;

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
in {
  inherit
    authFqdn
    authFqdnFor
    autoAuthDomains
    cookieDomain
    headscaleRedirectUri
    publicSsoInventoryDomains
    ssoDomains
    ;

  settings =
    {
      theme = "auto";
      default_2fa_method = "webauthn";
      server = {
        address = "tcp://127.0.0.1:${toString cfg.port}/";
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
}
