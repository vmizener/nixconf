{
  config,
  lib,
  ...
}: let
  flakeNet = config.mod.net;
in {
  ################
  # Flake-level network helpers & merged DNS records
  mod.net = {
    lib = rec {
      extractHostname = key: let
        noHttp = lib.removePrefix "http://" (lib.removePrefix "https://" key);
      in
        builtins.head (lib.splitString ":" noHttp);

      qualifyKey = key: let
        hostPart = extractHostname key;
      in
        if lib.hasInfix "." hostPart
        then key
        else builtins.replaceStrings [hostPart] ["${hostPart}.${flakeNet.domain}"] key;
    };

    allDnsRecords = let
      inherit (flakeNet.lib) extractHostname qualifyKey;
      proxyIpv4 =
        if flakeNet.proxyHost != null
        then (flakeNet.hosts.${flakeNet.proxyHost} or {}).ipv4 or null
        else null;

      hostRecords =
        lib.foldlAttrs (
          acc: host: h:
            acc
            // lib.optionalAttrs (h.ipv4 != null) {"${host}.${flakeNet.domain}" = h.ipv4;}
            // h.dnsRecords
        ) {}
        flakeNet.hosts;

      serviceRecords = lib.optionalAttrs (proxyIpv4 != null) (
        lib.foldlAttrs (
          acc: _: h:
            acc
            // lib.mapAttrs' (
              _: svc:
                lib.nameValuePair (extractHostname (qualifyKey svc.subdomain)) proxyIpv4
            )
            h.services
        ) {}
        flakeNet.hosts
      );
    in
      hostRecords // serviceRecords;
  };

  ################
  # NixOS static IP setup & cross-host collision assertions
  flake.nixosModules."common/net" = {
    config,
    lib,
    ...
  }: let
    hostName = config.networking.hostName;
    hostCfg = flakeNet.hosts.${hostName} or null;
    isVm = config.mod."feat/vm".isVm or false;
  in {
    networking = lib.mkIf (hostCfg != null && hostCfg.ipv4 != null && !isVm) {
      interfaces = lib.optionalAttrs (hostCfg.interface != null) {
        ${hostCfg.interface} = {
          useDHCP = false;
          ipv4.addresses = [
            {
              address = hostCfg.ipv4;
              inherit (hostCfg) prefixLength;
            }
          ];
        };
      };
      defaultGateway = lib.mkIf (hostCfg.gateway != null) hostCfg.gateway;
      nameservers = lib.mkIf (hostCfg.nameservers != []) hostCfg.nameservers;
    };

    assertions = let
      inherit (flakeNet.lib) extractHostname qualifyKey;

      duplicatesBy = keyFn: items:
        builtins.groupBy keyFn items
        |> lib.filterAttrs (_: group: builtins.length group > 1);

      proxyIpv4 =
        if flakeNet.proxyHost != null
        then (flakeNet.hosts.${flakeNet.proxyHost} or {}).ipv4 or null
        else null;

      ipv4Collisions =
        lib.mapAttrsToList (host: h: {
          inherit host;
          inherit (h) ipv4;
        })
        flakeNet.hosts
        |> builtins.filter (e: e.ipv4 != null)
        |> duplicatesBy (e: e.ipv4);

      serviceEntries =
        lib.mapAttrsToList (
          host: h:
            lib.mapAttrsToList (svcName: svc: {
              key = qualifyKey svc.subdomain;
              fqdn = extractHostname (qualifyKey svc.subdomain);
              source = "${host}.${svcName}";
            })
            h.services
        )
        flakeNet.hosts
        |> lib.concatLists;

      serviceCollisions = duplicatesBy (e: e.key) serviceEntries;

      hostDnsEntries =
        lib.mapAttrsToList (
          host: h: let
            records =
              (lib.optionalAttrs (h.ipv4 != null) {"${host}.${flakeNet.domain}" = h.ipv4;})
              // h.dnsRecords;
          in
            lib.mapAttrsToList (fqdn: ip: {
              inherit fqdn ip;
              source = "${host} (${ip})";
            })
            records
        )
        flakeNet.hosts
        |> lib.concatLists;

      serviceDnsEntries =
        lib.optionalAttrs (proxyIpv4 != null) (builtins.groupBy (e: e.fqdn) serviceEntries)
        |> lib.mapAttrsToList (fqdn: entries: {
          inherit fqdn;
          ip = proxyIpv4;
          source = "service ${lib.concatMapStringsSep "/" (e: e.source) entries} (${proxyIpv4})";
        });

      dnsCollisions = duplicatesBy (e: e.fqdn) (hostDnsEntries ++ serviceDnsEntries);
    in
      [
        {
          assertion = flakeNet.proxyHost == null || flakeNet.hosts ? ${flakeNet.proxyHost};
          message = "mod.net.proxyHost '${toString flakeNet.proxyHost}' is not declared in mod.net.hosts.";
        }
        {
          assertion = serviceEntries == [] || flakeNet.proxyHost != null;
          message = "mod.net.hosts defines services, but mod.net.proxyHost is not set.";
        }
      ]
      ++ lib.optional (hostCfg != null && hostCfg.ipv4 != null && !isVm) {
        assertion = hostCfg.interface != null;
        message = "mod.net.hosts.${hostName}.interface must be set when ipv4 is specified.";
      }
      ++ lib.mapAttrsToList (ip: entries: {
        assertion = false;
        message = "mod.net.hosts: static IPv4 '${ip}' is assigned to multiple hosts: ${lib.concatMapStringsSep ", " (e: e.host) entries}";
      })
      ipv4Collisions
      ++ lib.mapAttrsToList (key: entries: {
        assertion = false;
        message = "mod.net.hosts: colliding service subdomain '${key}' declared by multiple services: ${lib.concatMapStringsSep ", " (e: e.source) entries}";
      })
      serviceCollisions
      ++ lib.mapAttrsToList (fqdn: entries: {
        assertion = false;
        message = "mod.net.allDnsRecords: colliding DNS record '${fqdn}' published by multiple sources: ${lib.concatMapStringsSep ", " (e: e.source) entries}";
      })
      dnsCollisions;
  };
}
