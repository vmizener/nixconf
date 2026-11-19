# Virtual host synthesis across discovered services, explicit hosts, and ACME fallbacks.
{
  cfg,
  currentHost,
  endpoints,
  flakeNet,
  lib,
  managedAcmeDomains,
  netCfg,
}: let
  inherit (endpoints) parseEndpoint;

  mkProxyVhost = {
    access,
    acmeDomain,
    domainCfg,
    isHttpOnly,
    rootRedirect ? null,
    upstreamUrl,
    useSso,
  }: let
    wantsAcme = domainCfg != null && domainCfg.tls == "acme";
    useAcme = cfg.acme.enable && wantsAcme && !isHttpOnly;
    useInternalTls = !isHttpOnly && !useAcme && access == "lan";
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
  in
    {
      extraConfig =
        lib.optionalString useInternalTls "tls internal\n"
        + lib.optionalString (access == "lan") lanGuardConfig
        + lib.optionalString useSso forwardAuthConfig
        + lib.optionalString (rootRedirect != null) ''
          @root path /
          redir @root ${rootRedirect} 302
        ''
        + "reverse_proxy ${upstreamUrl}\n";
    }
    // lib.optionalAttrs useAcme {
      useACMEHost = acmeDomain;
    };

  # Auto-discover services declared across site.net.hosts and local mod."common/site/net".services
  discoveredServices = let
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
      domainCfg =
        if svc.domain != null
        then flakeNet.domains.${svc.domain} or null
        else null;
    in {
      inherit isLocal key svc svcName targetHostName targetIpv4 upstreamHost;
      fqdn = flakeNet.lib.extractHostname key;
      source = "${sourcePrefix}.${svcName}";
      vhost = mkProxyVhost {
        inherit domainCfg;
        inherit (svc) access rootRedirect;
        acmeDomain = svc.domain;
        isHttpOnly = lib.hasPrefix "http://" key;
        upstreamUrl = "${svc.protocol}://${upstreamHost}:${toString svc.port}";
        useSso = svc.auth == "sso";
      };
    };
  in
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
    lib.mapAttrsToList (rawKey: vhostVal: let
      key = flakeNet.lib.qualifyKey rawKey;
      fqdn = flakeNet.lib.extractHostname key;
      matchedDomain = flakeNet.lib.findDomainName fqdn;
      domainCfg =
        if matchedDomain != null
        then flakeNet.domains.${matchedDomain}
        else null;
      access =
        if domainCfg != null
        then domainCfg.access
        else "public";
    in {
      inherit access fqdn key matchedDomain rawKey;
      upstream =
        if builtins.isString vhostVal
        then parseEndpoint vhostVal
        else null;
      vhost =
        if builtins.isString vhostVal
        then
          mkProxyVhost {
            inherit access domainCfg;
            acmeDomain = matchedDomain;
            isHttpOnly = lib.hasPrefix "http://" key;
            upstreamUrl = vhostVal;
            useSso = domainCfg != null && domainCfg.defaultAuth == "sso";
          }
        else vhostVal;
    })
    cfg.virtualHosts;

  groupedExplicit = builtins.groupBy (e: e.key) explicitEntries;
  explicitVHosts = lib.mapAttrs (_: entries: (builtins.head entries).vhost) groupedExplicit;

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
in {
  inherit allVHosts discoveredServices explicitEntries;

  explicitCollisions = lib.filterAttrs (_: entries: builtins.length entries > 1) groupedExplicit;

  explicitDnsVHosts =
    lib.filterAttrs (
      key: _: !(lib.hasPrefix "*." (flakeNet.lib.extractHostname key))
    )
    explicitVHosts;

  hasPublicVHosts =
    builtins.any (d: d.svc.access == "public") discoveredServices
    || builtins.any (e: e.access == "public") explicitEntries;

  hasHttpsVHosts =
    builtins.any (k: !(lib.hasPrefix "http://" k)) (builtins.attrNames allVHosts);

  usesRuntimeAcmeCerts =
    builtins.any (v: (v.useACMEHost or null) != null) (builtins.attrValues allVHosts);
}
