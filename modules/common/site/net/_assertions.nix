# Cross-host IPv4, domain, tag, service, DNS, and port collision assertions for `common/site/net`.
{
  hostCfg,
  hostName,
  isVm,
  lib,
  netCfg,
  siteNet,
}: let
  inherit (siteNet.lib) domainsWithTag extractHostname hostRecordsFor proxyIpv4 qualifyService;
  declaredDomainNames = builtins.attrNames siteNet.domains;

  duplicatesBy = keyFn: items:
    builtins.groupBy keyFn items
    |> lib.filterAttrs (_: group: builtins.length group > 1);

  ipv4Collisions =
    lib.mapAttrsToList (host: h: {
      inherit host;
      inherit (h) ipv4;
    })
    siteNet.hosts
    |> builtins.filter (e: e.ipv4 != null)
    |> duplicatesBy (e: e.ipv4);

  mkServiceEntry = sourcePrefix: svcName: svc: let
    key = qualifyService svc;
    fqdn = extractHostname key;
    tagMatches =
      if svc.domainTag != null
      then domainsWithTag svc.domainTag
      else [];
  in {
    inherit fqdn key svc tagMatches;
    domainCfg =
      if svc.domain != null
      then siteNet.domains.${svc.domain} or null
      else null;
    source = "${sourcePrefix}.${svcName}";
  };

  siteServiceEntries =
    lib.mapAttrsToList (
      host: h:
        lib.mapAttrsToList (mkServiceEntry "site.net.hosts.${host}.services") h.services
    )
    siteNet.hosts
    |> lib.concatLists;

  localServiceEntries =
    lib.mapAttrsToList (mkServiceEntry "mod.\"common/site/net\".services") netCfg.services;

  # Proxied services targeting `hostName` (`site.net.hosts.<hostName>` + `mod."common/site/net".services`),
  # checked against `netCfg.ports.<backend>.tcp` to catch proxy/daemon port drift.
  localHostServiceEntries =
    (
      if hostCfg != null
      then lib.mapAttrsToList (mkServiceEntry "site.net.hosts.${hostName}.services") hostCfg.services
      else []
    )
    ++ localServiceEntries;

  # Exclusive `(proto, port)` collisions across active daemons on `hostName`.
  mkLocalPortCollisions = proto:
    lib.mapAttrsToList (
      daemon: pCfg:
        map (port: {inherit daemon port;}) pCfg.${proto}
    )
    netCfg.ports
    |> lib.concatLists
    |> duplicatesBy (e: toString e.port);

  localTcpCollisions = mkLocalPortCollisions "tcp";
  localUdpCollisions = mkLocalPortCollisions "udp";

  # Per-host port collisions across distinct `backend`s on remote `site.net.hosts`
  # entries (covers non-NixOS appliances while allowing multi-domain vhosts on one backend).
  remoteHostPortCollisions =
    siteNet.hosts
    |> lib.filterAttrs (host: _: host != hostName)
    |> lib.mapAttrsToList (
      host: h:
        lib.mapAttrsToList (mkServiceEntry "site.net.hosts.${host}.services") h.services
        |> builtins.groupBy (e: toString e.svc.port)
        |> lib.filterAttrs (_: group: builtins.length (lib.unique (map (e: e.svc.backend) group)) > 1)
        |> lib.mapAttrsToList (port: entries: {inherit entries host port;})
    )
    |> lib.concatLists;

  serviceEntries = siteServiceEntries ++ localServiceEntries;

  resolvedServiceEntries = builtins.filter (e: e.domainCfg != null) serviceEntries;
  serviceCollisions = duplicatesBy (e: e.key) resolvedServiceEntries;

  hostDnsEntries =
    lib.mapAttrsToList (
      host: h:
        lib.mapAttrsToList (fqdn: ip: {
          inherit fqdn ip;
          source = "${host} (${ip})";
        })
        (hostRecordsFor host h)
    )
    siteNet.hosts
    |> lib.concatLists;

  serviceDnsEntries =
    lib.optionalAttrs (proxyIpv4 != null) (
      resolvedServiceEntries
      |> builtins.filter (e: lib.hasInfix "." e.fqdn)
      |> builtins.groupBy (e: e.fqdn)
    )
    |> lib.mapAttrsToList (fqdn: entries: {
      inherit fqdn;
      ip = proxyIpv4;
      source = "service ${lib.concatMapStringsSep "/" (e: e.source) entries} (${proxyIpv4})";
    });

  dnsCollisions = duplicatesBy (e: e.fqdn) (hostDnsEntries ++ serviceDnsEntries);
in
  [
    {
      assertion = siteNet.domains ? ${siteNet.defaultDomain};
      message = "site.net.defaultDomain '${siteNet.defaultDomain}' is not declared in site.net.domains (available: ${lib.concatStringsSep ", " declaredDomainNames}).";
    }
    {
      assertion = siteNet.proxyHost == null || siteNet.hosts ? ${siteNet.proxyHost};
      message = "site.net.proxyHost '${toString siteNet.proxyHost}' is not declared in site.net.hosts.";
    }
    {
      assertion = serviceEntries == [] || siteNet.proxyHost != null;
      message = "Proxied services are declared, but site.net.proxyHost is not set.";
    }
    {
      assertion = netCfg.services == {} || siteNet.proxyHost == hostName;
      message = "mod.\"common/site/net\".services is non-empty on '${hostName}', which is not site.net.proxyHost ('${toString siteNet.proxyHost}'); declare remote host services under site.net.hosts.${hostName}.services instead.";
    }
    {
      assertion = !netCfg.forwardAuth.enable || netCfg.forwardAuth.address != null;
      message = "mod.\"common/site/net\".forwardAuth.address must be set when forwardAuth.enable is true.";
    }
  ]
  ++ lib.mapAttrsToList (dName: dCfg: {
    assertion = dCfg.tls != "acme" || lib.hasInfix "." dName;
    message = "site.net.domains.${dName}: tls = \"acme\" requires a public multi-label domain name (contains '.'), got '${dName}'.";
  })
  siteNet.domains
  ++ lib.mapAttrsToList (dName: dCfg: {
    assertion = dCfg.dnsAccount == null || siteNet.dns ? ${dCfg.dnsAccount};
    message = "site.net.domains.${dName}: dnsAccount '${toString dCfg.dnsAccount}' is not declared in site.net.dns (available: ${lib.concatStringsSep ", " (builtins.attrNames siteNet.dns)}).";
  })
  siteNet.domains
  ++ lib.optional (hostCfg != null && hostCfg.ipv4 != null && !isVm) {
    assertion = hostCfg.interface != null;
    message = "site.net.hosts.${hostName}.interface must be set when ipv4 is specified.";
  }
  ++ lib.optional (hostCfg != null && hostName != siteNet.proxyHost && hostCfg.services != {} && siteNet.proxyHost != null) {
    assertion = proxyIpv4 != null;
    message = "site.net.hosts.${siteNet.proxyHost}.ipv4 must be set so backend host '${hostName}' can allow inbound connections from proxyHost.";
  }
  ++ lib.concatMap (
    e: (
      if e.svc.domainTag != null && e.svc.domain == null
      then [
        {
          assertion = false;
          message =
            if e.tagMatches == []
            then "${e.source}: domainTag '${e.svc.domainTag}' matched no domains in site.net.domains."
            else "${e.source}: domainTag '${e.svc.domainTag}' is ambiguous (matched multiple domains: ${lib.concatStringsSep ", " e.tagMatches}); set `domain` explicitly or make the tag unique.";
        }
      ]
      else [
        {
          assertion = e.domainCfg != null;
          message = "${e.source}: references undeclared domain '${toString e.svc.domain}' (declared in site.net.domains: ${lib.concatStringsSep ", " declaredDomainNames}).";
        }
        {
          assertion = e.svc.domainTag == null || builtins.elem e.svc.domain e.tagMatches;
          message = "${e.source}: explicit domain '${toString e.svc.domain}' does not carry domainTag '${toString e.svc.domainTag}'.";
        }
        {
          assertion = e.svc.access != "public" || (e.domainCfg != null && e.domainCfg.tls == "acme");
          message = "${e.source}: access = \"public\" requires domain '${toString e.svc.domain}' to use tls = \"acme\".";
        }
      ]
    )
  )
  serviceEntries
  ++ lib.mapAttrsToList (ip: entries: {
    assertion = false;
    message = "site.net.hosts: static IPv4 '${ip}' is assigned to multiple hosts: ${lib.concatMapStringsSep ", " (e: e.host) entries}";
  })
  ipv4Collisions
  ++ lib.mapAttrsToList (key: entries: {
    assertion = false;
    message = "site.net.hosts: colliding service subdomain '${key}' declared by multiple services: ${lib.concatMapStringsSep ", " (e: e.source) entries}";
  })
  serviceCollisions
  ++ lib.mapAttrsToList (fqdn: entries: {
    assertion = false;
    message = "site.net.allDnsRecords: colliding DNS record '${fqdn}' published by multiple sources: ${lib.concatMapStringsSep ", " (e: e.source) entries}";
  })
  dnsCollisions
  ++ map (e: let
    backendTcp = (netCfg.ports.${e.svc.backend} or {}).tcp or [];
  in {
    assertion = builtins.elem e.svc.port backendTcp;
    message = "${e.source}: proxied port ${toString e.svc.port} does not match local '${e.svc.backend}' TCP port(s) (${lib.concatMapStringsSep ", " toString backendTcp}).";
  })
  localHostServiceEntries
  ++ lib.mapAttrsToList (port: entries: {
    assertion = false;
    message = "mod.\"common/site/net\".ports: TCP port ${port} on '${hostName}' is claimed by multiple services: ${lib.concatMapStringsSep ", " (e: e.daemon) entries}";
  })
  localTcpCollisions
  ++ lib.mapAttrsToList (port: entries: {
    assertion = false;
    message = "mod.\"common/site/net\".ports: UDP port ${port} on '${hostName}' is claimed by multiple services: ${lib.concatMapStringsSep ", " (e: e.daemon) entries}";
  })
  localUdpCollisions
  ++ map (c: {
    assertion = false;
    message = "site.net.hosts.${c.host}.services: port ${c.port} is assigned to multiple backends: ${lib.concatMapStringsSep ", " (e: "${e.svc.backend} (${e.source})") c.entries}";
  })
  remoteHostPortCollisions
