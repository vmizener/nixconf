/*
  feat/security/vaultwarden

Configures a self-hosted Vaultwarden password manager server behind Caddy on
NixOS (with automatic Split-DNS/proxy registration, local online SQLite
backups, optional SOPS-backed `/admin` token, and `nftables` egress sandboxing)
and Bitwarden desktop/CLI (`rbw`) clients in Home-Manager.

Exposes:

- flake.nixosModules."common/options" (options.mod."feat/security/vaultwarden")
- flake.nixosModules."feat/security/vaultwarden"
- flake.homeModules."common/options" (options.mod."feat/security/vaultwarden")
- flake.homeModules."feat/security/vaultwarden"
*/
{...} @ flake: let
  moduleName = "feat/security/vaultwarden";
  flakeNet = flake.config.site.net;

  mkDomainOptions = selfCfg: lib: {
    domainTag = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "dev";
      description = "Select the unique domain in `site.net.domains` carrying this tag.";
    };
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if selfCfg.domainTag != null
        then flakeNet.lib.resolveTag selfCfg.domainTag
        else null;
      defaultText = lib.literalExpression ''
        if config.mod."${moduleName}".domainTag != null
        then site.net.lib.resolveTag config.mod."${moduleName}".domainTag
        else null
      '';
      description = "Target domain key in `site.net.domains` hosting Vaultwarden (`<subdomain>.<domain>`).";
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "vault";
      description = "Subdomain label under `domain` where Vaultwarden is served.";
    };
  };
in {
  flake.nixosModules."common/options" = {
    config,
    lib,
    ...
  }: let
    selfCfg = config.mod.${moduleName};
    domainCfg =
      if selfCfg.domain != null
      then flakeNet.domains.${selfCfg.domain} or null
      else null;
  in {
    options.mod.${moduleName} =
      mkDomainOptions selfCfg lib
      // {
        port = lib.mkOption {
          type = lib.types.port;
          default = 8222;
          description = "Local loopback TCP port Vaultwarden listens on.";
        };
        access = lib.mkOption {
          type = lib.types.enum ["lan" "public"];
          default =
            if domainCfg != null
            then domainCfg.access
            else "lan";
          defaultText = lib.literalExpression ''domain.access or "lan"'';
          description = "Client reachability policy when auto-registering Vaultwarden on `site.net.proxyHost`.";
        };
        backupDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "/var/backup/vaultwarden";
          description = "Directory for NixOS's daily online SQLite backup timer (`null` disables local snapshots).";
        };
        signupsAllowed = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether open user registration is permitted without an invitation.";
        };
        enableAdmin = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to enable the `/admin` portal backed by `adminTokenSecret` or `environmentFiles`.";
        };
        adminTokenSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "services/vaultwarden/admin_token";
          description = "Key in `sops.secrets` providing the Argon2 PHC `ADMIN_TOKEN` hash when `enableAdmin` is true (`null` disables the default `sops` template).";
        };
        environmentFiles = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [];
          description = "Additional runtime `systemd.exec(5)` environment files passed to `vaultwarden.service`.";
        };
        extraConfig = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.nullOr (
              lib.types.oneOf [
                lib.types.bool
                lib.types.int
                lib.types.str
              ]
            )
          );
          default = {};
          description = "Additional environment settings merged into `services.vaultwarden.config`.";
        };
        egressSandbox = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Restrict outbound connections from `vaultwarden.service` via kernel `nftables` UID filtering.";
          };
          internet = lib.mkOption {
            type = lib.types.enum ["none" "restricted" "full"];
            default = "none";
            description = ''
              Outbound public internet policy for `vaultwarden.service`:
              - `"none"`: Strict air-gap (blocks external favicon fetches, HIBP checks, and mobile push relays).
              - `"restricted"`: Allow outbound HTTPS (`:443` TCP + loopback DNS) for Bitwarden push relays and HIBP breach checks.
              - `"full"`: Allow unrestricted public internet egress.
            '';
          };
        };
      };
  };

  flake.homeModules."common/options" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    selfCfg = config.mod.${moduleName};
    resolvedFqdn =
      if selfCfg.domain != null
      then flakeNet.lib.qualifyKeyFor selfCfg.domain selfCfg.subdomain
      else null;
  in {
    options.mod.${moduleName} =
      mkDomainOptions selfCfg lib
      // {
        baseUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default =
            if resolvedFqdn != null
            then "https://${resolvedFqdn}"
            else null;
          defaultText = lib.literalExpression ''
            if config.mod."${moduleName}".domain != null
            then "https://<subdomain>.<domain>"
            else null
          '';
          description = "Vaultwarden server URL configured in `rbw` (`null` uses upstream Bitwarden cloud default).";
        };
        email = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default =
            if flakeNet.adminEmails != []
            then builtins.head flakeNet.adminEmails
            else null;
          defaultText = lib.literalExpression "builtins.head site.net.adminEmails or null";
          description = "Account email address written to `rbw` settings when non-null.";
        };
        enableDesktop = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install the Bitwarden desktop GUI client (`pkgs.bitwarden-desktop`).";
        };
        enableCli = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable the `rbw` Bitwarden CLI and agent.";
        };
        lockTimeout = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 3600;
          description = "Seconds `rbw-agent` caches unlocked vault keys in memory.";
        };
        pinentry = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = pkgs.pinentry-curses;
          defaultText = lib.literalExpression "pkgs.pinentry-curses";
          description = "Pinentry package used by `rbw` when unlocking the vault.";
        };
      };
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
    currentHost = config.networking.hostName;
    serverFqdn =
      if cfg.domain != null
      then flakeNet.lib.qualifyKeyFor cfg.domain cfg.subdomain
      else null;
    tagMatches =
      if cfg.domainTag != null
      then flakeNet.lib.domainsWithTag cfg.domainTag
      else [];
    declaredInventoryFqdns =
      lib.concatMap (
        h:
          builtins.attrValues h.services
          |> map (svc: flakeNet.lib.extractHostname (flakeNet.lib.qualifyService svc))
      )
      (builtins.attrValues flakeNet.hosts);
    autoRegisterService =
      flakeNet.proxyHost
      == currentHost
      && cfg.domain != null
      && !(builtins.elem serverFqdn declaredInventoryFqdns);
    useDefaultAdminTemplate = cfg.enableAdmin && cfg.adminTokenSecret != null;
  in {
    assertions = [
      {
        assertion = cfg.domain != null && flakeNet.domains ? ${cfg.domain};
        message =
          if cfg.domainTag != null && cfg.domain == null
          then
            if tagMatches == []
            then "mod.\"${moduleName}\": domainTag '${cfg.domainTag}' matched no domains in site.net.domains."
            else "mod.\"${moduleName}\": domainTag '${cfg.domainTag}' is ambiguous (matched: ${lib.concatStringsSep ", " tagMatches}); set `domain` explicitly."
          else "mod.\"${moduleName}\".domain ('${toString cfg.domain}') must reference a declared domain in site.net.domains.";
      }
      {
        assertion = !cfg.enableAdmin || cfg.adminTokenSecret != null || cfg.environmentFiles != [];
        message = "mod.\"${moduleName}\": enableAdmin = true requires either `adminTokenSecret` to be non-null or `environmentFiles` to provide ADMIN_TOKEN.";
      }
    ];

    mod = {
      meta.imported = [moduleName];
      "common/site/net" = {
        ports.vaultwarden.tcp = [cfg.port];
        services = lib.optionalAttrs autoRegisterService {
          vaultwarden = {
            inherit (cfg) access domain port subdomain;
            auth = "none";
          };
        };
      };
      "common/firewall".egress.vaultwarden = {
        enable = cfg.egressSandbox.enable;
        required = true;
        allowDns = cfg.egressSandbox.internet != "none";
        allowPrivate = false;
        inherit (cfg.egressSandbox) internet;
        publicPorts = lib.optionalAttrs (cfg.egressSandbox.internet == "restricted") {
          tcp = [443];
        };
      };
    };

    sops = lib.mkIf useDefaultAdminTemplate {
      secrets.${cfg.adminTokenSecret} = {};
      templates."vaultwarden-admin.env" = {
        owner = config.users.users.vaultwarden.name;
        content = "ADMIN_TOKEN=${config.sops.placeholder.${cfg.adminTokenSecret}}\n";
      };
    };

    services.vaultwarden = {
      enable = true;
      inherit (cfg) backupDir;
      domain = serverFqdn;
      environmentFile =
        lib.optional useDefaultAdminTemplate config.sops.templates."vaultwarden-admin.env".path
        ++ cfg.environmentFiles;
      config =
        {
          ROCKET_ADDRESS = lib.mkDefault "127.0.0.1";
          ROCKET_PORT = cfg.port;
          SIGNUPS_ALLOWED = cfg.signupsAllowed;
          INVITATIONS_ALLOWED = lib.mkDefault true;
          SHOW_PASSWORD_HINT = lib.mkDefault false;
          DISABLE_ICON_DOWNLOAD = lib.mkDefault (
            cfg.egressSandbox.enable && cfg.egressSandbox.internet == "none"
          );
        }
        // cfg.extraConfig;
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.meta.imported = [moduleName];

    home.packages = lib.optional cfg.enableDesktop pkgs.bitwarden-desktop;

    programs.rbw = lib.mkIf cfg.enableCli {
      enable = true;
      settings = lib.mkIf (cfg.email != null) {
        inherit (cfg) email pinentry;
        base_url = cfg.baseUrl;
        lock_timeout = cfg.lockTimeout;
      };
    };
  };
}
