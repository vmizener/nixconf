/*
  feat/net/caddy

Enables Caddy web server and reverse proxy for the local network.

Exposes:

- flake.nixosModules."feat/net/caddy":
*/
{...} @ flake: let
  moduleName = "feat/net/caddy";
in {
  flake.nixosModules."common/options" = {
    lib,
    pkgs,
    ...
  }: {
    options.mod.${moduleName} = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.caddy;
        description = "Caddy package to use";
      };
      httpPort = lib.mkOption {
        type = lib.types.port;
        default = 80;
        description = "HTTP listen port";
      };
      httpsPort = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "HTTPS listen port";
      };
      localCerts = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Issue internal CA certificates for all virtual hosts by default";
      };
      virtualHosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.either lib.types.str (lib.types.attrsOf lib.types.anything)
        );
        default = {};
        description = ''
          Declarative virtual hosts. Keys without a dot automatically get `.${flake.config.mod.net.domain}` appended.
          Values can be either an upstream URL/address string (shorthand for `reverse_proxy <upstream>`)
          or a `services.caddy.virtualHosts` submodule attrset.
        '';
      };
      enableConfigCheck = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Validate the generated Caddy configuration at build time";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open the HTTP and HTTPS ports in the firewall";
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
    currentHost = config.networking.hostName;
    hostIpv4 = (flake.config.mod.net.hosts.${currentHost} or {}).ipv4 or null;

    # Auto-discover services declared across mod.net.hosts
    discoveredVHosts =
      lib.foldlAttrs (
        acc: targetHostName: h: let
          upstreamHost =
            if targetHostName == currentHost
            then "127.0.0.1"
            else if h.ipv4 != null
            then h.ipv4
            else "${targetHostName}.local";
          hostSvcs =
            lib.mapAttrs' (
              _: svc:
                lib.nameValuePair
                (flake.config.mod.net.lib.qualifyKey svc.subdomain)
                {extraConfig = "reverse_proxy ${svc.protocol}://${upstreamHost}:${toString svc.port}";}
            )
            h.services;
        in
          acc // hostSvcs
      ) {}
      flake.config.mod.net.hosts;

    explicitEntries =
      lib.mapAttrsToList (rawKey: vhost: {
        inherit rawKey;
        key = flake.config.mod.net.lib.qualifyKey rawKey;
        vhost =
          if builtins.isString vhost
          then {extraConfig = "reverse_proxy ${vhost}";}
          else vhost;
      })
      cfg.virtualHosts;

    groupedExplicit = builtins.groupBy (e: e.key) explicitEntries;
    explicitCollisions = lib.filterAttrs (_: entries: builtins.length entries > 1) groupedExplicit;
    explicitVHosts = lib.mapAttrs (_: entries: (builtins.head entries).vhost) groupedExplicit;

    allVHosts = discoveredVHosts // explicitVHosts;
  in {
    assertions =
      [
        {
          assertion = flake.config.mod.net.proxyHost == currentHost;
          message = "Host '${currentHost}' imports ${moduleName}; set mod.net.proxyHost = \"${currentHost}\" so service DNS records point to this proxy.";
        }
      ]
      ++ lib.mapAttrsToList (key: entries: {
        assertion = false;
        message =
          "mod.\"${moduleName}\".virtualHosts: multiple keys qualify to '${key}': "
          + lib.concatMapStringsSep ", " (e: "'${e.rawKey}'") entries;
      })
      explicitCollisions;

    mod = {
      imported = [moduleName];
      "feat/net/blocky".customDNS = lib.mkIf (hostIpv4 != null) (
        lib.mapAttrs' (
          key: _:
            lib.nameValuePair (flake.config.mod.net.lib.extractHostname key) (lib.mkDefault hostIpv4)
        )
        explicitVHosts
      );
    };

    services.caddy = {
      enable = true;
      inherit (cfg) package httpPort httpsPort openFirewall;
      globalConfig = lib.optionalString cfg.localCerts ''
        local_certs
      '';
      virtualHosts = allVHosts;
    };

    system.checks = lib.mkIf cfg.enableConfigCheck [
      (pkgs.runCommand "check-caddy-config" {} ''
        export XDG_DATA_HOME="$TMPDIR/data"
        export XDG_CONFIG_HOME="$TMPDIR/config"
        mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
        ${lib.getExe cfg.package} validate --adapter caddyfile --config ${config.services.caddy.configFile} && touch $out
      '')
    ];
  };
}
