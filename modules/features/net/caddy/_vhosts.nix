# Virtual host synthesis and upstream endpoint helpers for `feat/net/caddy`.
{
  cfg,
  currentHost,
  flakeNet,
  lib,
}: let
  parseEndpoint = raw: let
    stripped =
      raw
      |> lib.removePrefix "http://"
      |> lib.removePrefix "https://";
    hostAndPort = builtins.head (lib.splitString "/" stripped);
    ipv6Parts = lib.splitString "]:" (lib.removePrefix "[" hostAndPort);
    ipv4Match = builtins.match "^([^:]+):([0-9]+)$" hostAndPort;
  in
    if
      lib.hasPrefix "[" hostAndPort
      && builtins.length ipv6Parts == 2
      && builtins.match "^[0-9]+$" (builtins.elemAt ipv6Parts 1) != null
    then {
      host = builtins.elemAt ipv6Parts 0;
      port = lib.toInt (builtins.elemAt ipv6Parts 1);
    }
    else if ipv4Match != null
    then {
      host = builtins.elemAt ipv4Match 0;
      port = lib.toInt (builtins.elemAt ipv4Match 1);
    }
    else null;

  isLoopbackHost = h: builtins.elem h ["localhost" "127.0.0.1" "::1"];
  isIpv4Literal = h: builtins.match "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$" h != null;
  isIpv6Literal = h: lib.hasInfix ":" h;

  isLanDomain = fqdn:
    fqdn == flakeNet.domain || lib.hasSuffix ".${flakeNet.domain}" fqdn;

  isPublicManagedDomain = fqdn:
    flakeNet.publicDomain
    != null
    && (fqdn == flakeNet.publicDomain || lib.hasSuffix ".${flakeNet.publicDomain}" fqdn);

  lanGuardConfig =
    if cfg.lanCidrs == []
    then "abort\n"
    else ''
      @not_lan not remote_ip ${lib.concatStringsSep " " cfg.lanCidrs}
      abort @not_lan
    '';

  forwardAuthConfig = ''
    forward_auth ${toString cfg.forwardAuth.address} {
      uri ${cfg.forwardAuth.uri}
      ${lib.optionalString (cfg.forwardAuth.copyHeaders != []) "copy_headers ${lib.concatStringsSep " " cfg.forwardAuth.copyHeaders}"}
    }
  '';

  # Auto-discover services declared across inventory.net.hosts
  discoveredServices = lib.concatLists (
    lib.mapAttrsToList (
      targetHostName: h: let
        isLocal = targetHostName == currentHost;
        upstreamHost =
          if isLocal
          then "127.0.0.1"
          else if h.ipv4 != null
          then h.ipv4
          else "${targetHostName}.local";
      in
        lib.mapAttrsToList (svcName: svc: let
          key = flakeNet.lib.qualifyService svc;
          fqdn = flakeNet.lib.extractHostname key;
          isHttpOnly = lib.hasPrefix "http://" key;
          vhost =
            if svc.visibility == "lan"
            then {
              extraConfig =
                lib.optionalString (!isHttpOnly) "tls internal\n"
                + lanGuardConfig
                + "reverse_proxy ${svc.protocol}://${upstreamHost}:${toString svc.port}\n";
            }
            else
              {
                extraConfig =
                  lib.optionalString (svc.auth == "sso") forwardAuthConfig
                  + "reverse_proxy ${svc.protocol}://${upstreamHost}:${toString svc.port}\n";
              }
              // lib.optionalAttrs (cfg.acme.enable && isPublicManagedDomain fqdn && !isHttpOnly) {
                useACMEHost = flakeNet.publicDomain;
              };
        in {
          inherit fqdn isLocal key svc svcName targetHostName upstreamHost vhost;
          targetIpv4 = h.ipv4;
          source = "${targetHostName}.${svcName}";
        })
        h.services
    )
    flakeNet.hosts
  );

  discoveredVHosts = builtins.listToAttrs (
    map (d: lib.nameValuePair d.key d.vhost) discoveredServices
  );

  explicitEntries =
    lib.mapAttrsToList (rawKey: vhost: let
      key = flakeNet.lib.qualifyKey rawKey;
      fqdn = flakeNet.lib.extractHostname key;
      isHttpOnly = lib.hasPrefix "http://" key;
      isLan = isLanDomain fqdn;
      upstream =
        if builtins.isString vhost
        then parseEndpoint vhost
        else null;
      normalizedVhost =
        if builtins.isString vhost
        then
          {
            extraConfig =
              lib.optionalString (isLan && !isHttpOnly) "tls internal\n"
              + lib.optionalString isLan lanGuardConfig
              + "reverse_proxy ${vhost}\n";
          }
          // lib.optionalAttrs (!isLan && cfg.acme.enable && isPublicManagedDomain fqdn && !isHttpOnly) {
            useACMEHost = flakeNet.publicDomain;
          }
        else vhost;
    in {
      inherit fqdn isLan key rawKey upstream;
      vhost = normalizedVhost;
    })
    cfg.virtualHosts;

  groupedExplicit = builtins.groupBy (e: e.key) explicitEntries;
  explicitCollisions = lib.filterAttrs (_: entries: builtins.length entries > 1) groupedExplicit;
  explicitVHosts = lib.mapAttrs (_: entries: (builtins.head entries).vhost) groupedExplicit;

  explicitDnsVHosts =
    lib.filterAttrs (
      key: _: !(lib.hasPrefix "*." (flakeNet.lib.extractHostname key))
    )
    explicitVHosts;

  wildcardFallbackVHost =
    lib.optionalAttrs (
      cfg.acme.enable
      && flakeNet.publicDomain != null
      && !(discoveredVHosts ? "*.${flakeNet.publicDomain}")
      && !(explicitVHosts ? "*.${flakeNet.publicDomain}")
    ) {
      "*.${flakeNet.publicDomain}" = {
        useACMEHost = flakeNet.publicDomain;
        extraConfig = ''
          abort
        '';
      };
    };

  allVHosts = wildcardFallbackVHost // discoveredVHosts // explicitVHosts;

  hasPublicVHosts =
    builtins.any (d: d.svc.visibility == "public") discoveredServices
    || builtins.any (e: !e.isLan) explicitEntries
    || cfg.acme.enable;

  hasHttpsVHosts =
    builtins.any (k: !(lib.hasPrefix "http://" k)) (builtins.attrNames allVHosts);

  usesRuntimeAcmeCerts =
    builtins.any (v: (v.useACMEHost or null) != null) (builtins.attrValues allVHosts);
in {
  inherit
    allVHosts
    discoveredServices
    explicitCollisions
    explicitDnsVHosts
    explicitEntries
    hasHttpsVHosts
    hasPublicVHosts
    isIpv4Literal
    isIpv6Literal
    isLoopbackHost
    parseEndpoint
    usesRuntimeAcmeCerts
    ;
}
