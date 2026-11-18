# Domain tag resolution, hostname qualification, and merged DNS synthesis for `site.net`.
{
  lib,
  siteNet,
}: let
  netLib = rec {
    extractHostname = key: let
      noHttp = lib.removePrefix "http://" (lib.removePrefix "https://" key);
    in
      builtins.head (lib.splitString ":" noHttp);

    matchesDomain = domain: fqdn:
      fqdn == domain || lib.hasSuffix ".${domain}" fqdn;

    domainsWithTag = tag:
      siteNet.domains
      |> lib.filterAttrs (_: dCfg: builtins.elem tag dCfg.tags)
      |> builtins.attrNames;

    resolveTag = tag: let
      matches = domainsWithTag tag;
    in
      if builtins.length matches == 1
      then builtins.head matches
      else null;

    findDomainName = fqdn: let
      matching =
        builtins.attrNames siteNet.domains
        |> builtins.filter (d: matchesDomain d fqdn)
        |> builtins.sort (a: b: builtins.stringLength a > builtins.stringLength b);
    in
      if matching == []
      then null
      else builtins.head matching;

    qualifyKeyFor = baseDomain: key: let
      hostPart = extractHostname key;
    in
      if baseDomain == null
      then key
      else if hostPart == "@"
      then builtins.replaceStrings ["@"] [baseDomain] key
      else if hostPart == ""
      then baseDomain
      else if matchesDomain baseDomain hostPart || lib.hasInfix "." hostPart
      then key
      else builtins.replaceStrings [hostPart] ["${hostPart}.${baseDomain}"] key;

    qualifyKey = qualifyKeyFor siteNet.defaultDomain;

    qualifyService = svc: let
      hostPart = extractHostname svc.subdomain;
      qualifiedSub =
        if svc.domain == null
        then hostPart
        else if hostPart == "@" || hostPart == ""
        then svc.domain
        else if matchesDomain svc.domain hostPart
        then hostPart
        else "${hostPart}.${svc.domain}";
    in
      if svc.domain == null
      then svc.subdomain
      else if hostPart == ""
      then svc.domain
      else builtins.replaceStrings [hostPart] [qualifiedSub] svc.subdomain;
  };

  proxyIpv4 =
    if siteNet.proxyHost != null
    then (siteNet.hosts.${siteNet.proxyHost} or {}).ipv4 or null
    else null;

  publishedHostDomains =
    siteNet.domains
    |> lib.filterAttrs (_: dCfg: dCfg.publishHosts)
    |> builtins.attrNames;

  hostRecordsFor = host: h:
    (lib.optionalAttrs (h.ipv4 != null) (
      builtins.listToAttrs (
        map (d: lib.nameValuePair "${host}.${d}" h.ipv4) publishedHostDomains
      )
    ))
    // h.dnsRecords;

  hostRecords =
    lib.foldlAttrs (
      acc: host: h:
        acc // hostRecordsFor host h
    ) {}
    siteNet.hosts;

  serviceRecords = lib.optionalAttrs (proxyIpv4 != null) (
    lib.foldlAttrs (
      acc: _: h:
        acc
        // (
          h.services
          |> lib.filterAttrs (
            _: svc: svc.domain != null && lib.hasInfix "." (netLib.extractHostname (netLib.qualifyService svc))
          )
          |> lib.mapAttrs' (
            _: svc:
              lib.nameValuePair (netLib.extractHostname (netLib.qualifyService svc)) proxyIpv4
          )
        )
    ) {}
    siteNet.hosts
  );
in {
  netLib = netLib // {inherit hostRecordsFor proxyIpv4;};
  allDnsRecords = hostRecords // serviceRecords;
}
