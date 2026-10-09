/*
  feat/net/caddy

Enables Caddy web server and reverse proxy for the local network.

Exposes:

- flake.nixosModules."feat/net/caddy":
*/
{self, ...}: let
  moduleName = "feat/net/caddy";
in {
  flake.nixosModules."common/options" = {
    config,
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
          Declarative virtual hosts. Keys without a dot automatically get `.${config.mod.net.domain}` appended.
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
    domain = config.mod.net.domain;

    # Strip scheme and port from a Caddy virtualHost key to extract the DNS hostname
    extractHostname = key: let
      noHttp = lib.removePrefix "http://" (lib.removePrefix "https://" key);
    in
      builtins.head (lib.splitString ":" noHttp);

    # Append .<domain> if the hostname has no dot
    qualifyKey = key: let
      hostPart = extractHostname key;
    in
      if lib.hasInfix "." hostPart
      then key
      else builtins.replaceStrings [hostPart] ["${hostPart}.${domain}"] key;

    # Auto-discover mod.net.services across all nixosConfigurations
    discoveredVHosts =
      lib.foldlAttrs (
        acc: _: hostconf: let
          targetHostName = hostconf.config.networking.hostName;
          upstreamHost =
            if targetHostName == config.networking.hostName
            then "127.0.0.1"
            else if hostconf.config.mod.net.ipv4 != null
            then hostconf.config.mod.net.ipv4
            else "${targetHostName}.local";
          hostSvcs =
            lib.mapAttrs' (
              _: svc:
                lib.nameValuePair
                (qualifyKey svc.subdomain)
                {extraConfig = "reverse_proxy ${svc.protocol}://${upstreamHost}:${toString svc.port}";}
            )
            hostconf.config.mod.net.services;
        in
          acc // hostSvcs
      ) {}
      self.nixosConfigurations;

    explicitVHosts =
      lib.mapAttrs' (
        key: vhost:
          lib.nameValuePair
          (qualifyKey key)
          (
            if builtins.isString vhost
            then {extraConfig = "reverse_proxy ${vhost}";}
            else vhost
          )
      )
      cfg.virtualHosts;

    allVHosts = discoveredVHosts // explicitVHosts;
  in {
    mod = {
      imported = [moduleName];
      net.dnsRecords = lib.mkIf (config.mod.net.ipv4 != null) (
        lib.mapAttrs' (
          key: _:
            lib.nameValuePair (extractHostname key) config.mod.net.ipv4
        )
        allVHosts
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
