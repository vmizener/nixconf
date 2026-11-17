# Virtual host synthesis and upstream endpoint helpers for `feat/net/caddy`.
{
  cfg,
  currentHost,
  flakeNet,
  lib,
  managedAcmeDomains,
  netCfg,
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

  lanGuardConfig =
    if netCfg.trustedCidrs == []
    then "abort\n"
    else ''
      @not_lan not remote_ip ${lib.concatStringsSep " " netCfg.trustedCidrs}
      abort @not_lan
    '';

  forwardAuthConfig = ''
    forward_auth ${toString netCfg.forwardAuth.address} {
      uri /api/authz/forward-auth
      copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }
  '';

  mkDiscoveredService = {
    isLocal,
    sourcePrefix,
    svc,
    svcName,
    targetHostName,
    targetIpv4,
    upstreamHost,
  }: let
    key = flakeNet.lib.qualifyService svc;
    fqdn = flakeNet.lib.extractHostname key;
    isHttpOnly = lib.hasPrefix "http://" key;
    domainCfg =
      if svc.domain != null
      then flakeNet.domains.${svc.domain} or null
      else null;
    wantsAcme = domainCfg != null && domainCfg.tls == "acme";
    useAcme = cfg.acme.enable && wantsAcme && !isHttpOnly;
    useInternalTls = !isHttpOnly && !useAcme && svc.access == "lan";
    restrictToLan = svc.access == "lan";
    vhost =
      {
        extraConfig =
          lib.optionalString useInternalTls "tls internal\n"
          + lib.optionalString restrictToLan lanGuardConfig
          + lib.optionalString (svc.auth == "sso") forwardAuthConfig
          + lib.optionalString (svc.rootRedirect != null) ''
            @root path /
            redir @root ${svc.rootRedirect} 302
          ''
          + "reverse_proxy ${svc.protocol}://${upstreamHost}:${toString svc.port}\n";
      }
      // lib.optionalAttrs useAcme {
        useACMEHost = svc.domain;
      };
  in {
    inherit fqdn isLocal key svc svcName targetHostName targetIpv4 upstreamHost vhost;
    source = "${sourcePrefix}.${svcName}";
  };

  # Auto-discover services declared across inventory.net.hosts and local mod."common/net".services
  discoveredServices =
    lib.concatLists (
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
          lib.mapAttrsToList (
            svcName: svc:
              mkDiscoveredService {
                inherit isLocal svc svcName targetHostName upstreamHost;
                sourcePrefix = targetHostName;
                targetIpv4 = h.ipv4;
              }
          )
          h.services
      )
      flakeNet.hosts
    )
    ++ lib.mapAttrsToList (
      svcName: svc:
        mkDiscoveredService {
          inherit svc svcName;
          isLocal = true;
          sourcePrefix = "${currentHost}.local";
          targetHostName = currentHost;
          targetIpv4 = (flakeNet.hosts.${currentHost} or {}).ipv4 or null;
          upstreamHost = "127.0.0.1";
        }
    )
    netCfg.services;

  discoveredVHosts = builtins.listToAttrs (
    map (d: lib.nameValuePair d.key d.vhost) discoveredServices
  );

  explicitEntries =
    lib.mapAttrsToList (rawKey: vhost: let
      key = flakeNet.lib.qualifyKey rawKey;
      fqdn = flakeNet.lib.extractHostname key;
      isHttpOnly = lib.hasPrefix "http://" key;
      matchedDomain = flakeNet.lib.findDomainName fqdn;
      domainCfg =
        if matchedDomain != null
        then flakeNet.domains.${matchedDomain}
        else null;
      access =
        if domainCfg != null
        then domainCfg.access
        else "public";
      wantsAcme = domainCfg != null && domainCfg.tls == "acme";
      useAcme = cfg.acme.enable && wantsAcme && !isHttpOnly;
      useInternalTls = !isHttpOnly && !useAcme && access == "lan";
      upstream =
        if builtins.isString vhost
        then parseEndpoint vhost
        else null;
      normalizedVhost =
        if builtins.isString vhost
        then
          {
            extraConfig =
              lib.optionalString useInternalTls "tls internal\n"
              + lib.optionalString (access == "lan") lanGuardConfig
              + lib.optionalString (domainCfg != null && domainCfg.defaultAuth == "sso") forwardAuthConfig
              + "reverse_proxy ${vhost}\n";
          }
          // lib.optionalAttrs useAcme {
            useACMEHost = matchedDomain;
          }
        else vhost;
    in {
      inherit access fqdn key matchedDomain rawKey upstream;
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

  wildcardFallbackVHosts = lib.optionalAttrs cfg.acme.enable (
    managedAcmeDomains
    |> builtins.filter (
      d: !(discoveredVHosts ? "*.${d}") && !(explicitVHosts ? "*.${d}")
    )
    |> map (
      d:
        lib.nameValuePair "*.${d}" {
          useACMEHost = d;
          extraConfig = ''
            abort
          '';
        }
    )
    |> builtins.listToAttrs
  );

  allVHosts = wildcardFallbackVHosts // discoveredVHosts // explicitVHosts;

  hasPublicVHosts =
    builtins.any (d: d.svc.access == "public") discoveredServices
    || builtins.any (e: e.access == "public") explicitEntries;

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
