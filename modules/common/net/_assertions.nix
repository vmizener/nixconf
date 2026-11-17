# Cross-host IPv4, domain, tag, service, and DNS collision assertions for `common/net`.
{
  dns,
  flakeNet,
  hostCfg,
  hostName,
  isVm,
  lib,
  netCfg,
}: let
  inherit (dns) hostRecordsFor netLib proxyIpv4;
  inherit (netLib) domainsWithTag extractHostname qualifyService;
  declaredDomainNames = builtins.attrNames flakeNet.domains;

  duplicatesBy = keyFn: items:
    builtins.groupBy keyFn items
    |> lib.filterAttrs (_: group: builtins.length group > 1);

  ipv4Collisions =
    lib.mapAttrsToList (host: h: {
      inherit host;
      inherit (h) ipv4;
    })
    flakeNet.hosts
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
      then flakeNet.domains.${svc.domain} or null
      else null;
    source = "${sourcePrefix}.${svcName}";
  };

  inventoryServiceEntries =
    lib.mapAttrsToList (
      host: h:
        lib.mapAttrsToList (mkServiceEntry "inventory.net.hosts.${host}.services") h.services
    )
    flakeNet.hosts
    |> lib.concatLists;

  localServiceEntries =
    lib.mapAttrsToList (mkServiceEntry "mod.\"common/net\".services") netCfg.services;

  serviceEntries = inventoryServiceEntries ++ localServiceEntries;

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
    flakeNet.hosts
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
      assertion = flakeNet.domains ? ${flakeNet.defaultDomain};
      message = "inventory.net.defaultDomain '${flakeNet.defaultDomain}' is not declared in inventory.net.domains (available: ${lib.concatStringsSep ", " declaredDomainNames}).";
    }
    {
      assertion = flakeNet.proxyHost == null || flakeNet.hosts ? ${flakeNet.proxyHost};
      message = "inventory.net.proxyHost '${toString flakeNet.proxyHost}' is not declared in inventory.net.hosts.";
    }
    {
      assertion = serviceEntries == [] || flakeNet.proxyHost != null;
      message = "Proxied services are declared, but inventory.net.proxyHost is not set.";
    }
    {
      assertion = netCfg.services == {} || flakeNet.proxyHost == hostName;
      message = "mod.\"common/net\".services is non-empty on '${hostName}', which is not inventory.net.proxyHost ('${toString flakeNet.proxyHost}'); declare remote host services under inventory.net.hosts.${hostName}.services instead.";
    }
    {
      assertion = !netCfg.forwardAuth.enable || netCfg.forwardAuth.address != null;
      message = "mod.\"common/net\".forwardAuth.address must be set when forwardAuth.enable is true.";
    }
  ]
  ++ lib.mapAttrsToList (dName: dCfg: {
    assertion = dCfg.tls != "acme" || lib.hasInfix "." dName;
    message = "inventory.net.domains.${dName}: tls = \"acme\" requires a public multi-label domain name (contains '.'), got '${dName}'.";
  })
  flakeNet.domains
  ++ lib.mapAttrsToList (dName: dCfg: {
    assertion = dCfg.dnsAccount == null || flakeNet.dns ? ${dCfg.dnsAccount};
    message = "inventory.net.domains.${dName}: dnsAccount '${toString dCfg.dnsAccount}' is not declared in inventory.net.dns (available: ${lib.concatStringsSep ", " (builtins.attrNames flakeNet.dns)}).";
  })
  flakeNet.domains
  ++ lib.optional (hostCfg != null && hostCfg.ipv4 != null && !isVm) {
    assertion = hostCfg.interface != null;
    message = "inventory.net.hosts.${hostName}.interface must be set when ipv4 is specified.";
  }
  ++ lib.concatMap (
    e: (
      if e.svc.domainTag != null && e.svc.domain == null
      then [
        {
          assertion = false;
          message =
            if e.tagMatches == []
            then "${e.source}: domainTag '${e.svc.domainTag}' matched no domains in inventory.net.domains."
            else "${e.source}: domainTag '${e.svc.domainTag}' is ambiguous (matched multiple domains: ${lib.concatStringsSep ", " e.tagMatches}); set `domain` explicitly or make the tag unique.";
        }
      ]
      else [
        {
          assertion = e.domainCfg != null;
          message = "${e.source}: references undeclared domain '${toString e.svc.domain}' (declared in inventory.net.domains: ${lib.concatStringsSep ", " declaredDomainNames}).";
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
    message = "inventory.net.hosts: static IPv4 '${ip}' is assigned to multiple hosts: ${lib.concatMapStringsSep ", " (e: e.host) entries}";
  })
  ipv4Collisions
  ++ lib.mapAttrsToList (key: entries: {
    assertion = false;
    message = "inventory.net.hosts: colliding service subdomain '${key}' declared by multiple services: ${lib.concatMapStringsSep ", " (e: e.source) entries}";
  })
  serviceCollisions
  ++ lib.mapAttrsToList (fqdn: entries: {
    assertion = false;
    message = "inventory.net.allDnsRecords: colliding DNS record '${fqdn}' published by multiple sources: ${lib.concatMapStringsSep ", " (e: e.source) entries}";
  })
  dnsCollisions
