# Provider, zone, CIDR, port-range, fallback, and egress-sandbox assertions for `common/firewall`.
{
  activeProviders,
  cfg,
  config,
  lib,
  moduleName,
}: let
  enabledIds = map (p: p.id) (activeProviders cfg.providers);
  declaredZoneNames = builtins.attrNames cfg.zones;

  isLoopback = s: builtins.elem s ["localhost" "127.0.0.1" "::1"];
  isIpv4 = s:
    builtins.match "^[0-9]{1,3}(\\.[0-9]{1,3}){3}(/([0-9]|[12][0-9]|3[0-2]))?$" s != null;
  isIpv6 = s:
    lib.hasInfix ":" s
    && builtins.match "^[0-9a-fA-F:]+(/([0-9]|[1-9][0-9]|1[01][0-9]|12[0-8]))?$" s != null;
  isValidCidrOrIp = s: isIpv4 s || isIpv6 s;
  isValidTargetAddress = s: isLoopback s || isValidCidrOrIp s;

  sanitizeId = name: builtins.replaceStrings ["-" "."] ["_" "_"] name;

  duplicatesBy = keyFn: items:
    builtins.groupBy keyFn items
    |> lib.filterAttrs (_: group: builtins.length group > 1);

  enabledIngress = lib.filterAttrs (_: r: r.enable) cfg.ingress;
  enabledForwardRules = lib.filterAttrs (_: r: r.enable) cfg.forward.rules;
  enabledEgress = lib.filterAttrs (_: e: e.enable) cfg.egress;

  egressIdCollisions =
    builtins.attrNames enabledEgress
    |> duplicatesBy sanitizeId;

  egressUnitCollisions =
    lib.mapAttrsToList (
      policy: e:
        map (unit: {inherit policy unit;}) e.systemdUnits
    )
    enabledEgress
    |> lib.concatLists
    |> duplicatesBy (x: x.unit);
in
  [
    {
      assertion = builtins.length enabledIds <= 1;
      message = ''mod."${moduleName}".providers: multiple firewall providers enabled (${lib.concatStringsSep ", " enabledIds}); at most one provider may be active.'';
    }
    {
      assertion = !cfg.forward.enable || cfg.enable;
      message = ''mod."${moduleName}".forward.enable = true requires an active firewall provider (e.g. flake.nixosModules."feat/system/firewall").'';
    }
  ]
  ++ lib.concatLists (
    lib.mapAttrsToList (zName: zCfg: let
      invalidCidrs = builtins.filter (c: !(isValidCidrOrIp c)) zCfg.cidrs;
    in [
      {
        assertion = invalidCidrs == [];
        message = ''mod."${moduleName}".zones.${zName}.cidrs: invalid IPv4/IPv6 CIDR(s): ${lib.concatStringsSep ", " invalidCidrs}.'';
      }
    ])
    cfg.zones
  )
  ++ lib.concatLists (
    lib.mapAttrsToList (rName: rCfg: let
      unknownZones = builtins.filter (z: !(cfg.zones ? ${z})) rCfg.zones;
      badRanges =
        (rCfg.tcpRanges ++ rCfg.udpRanges)
        |> builtins.filter (rng: rng.from > rng.to);
    in [
      {
        assertion = unknownZones == [];
        message = ''mod."${moduleName}".ingress.${rName}.zones: references undeclared zone(s): ${lib.concatStringsSep ", " unknownZones} (declared: ${lib.concatStringsSep ", " declaredZoneNames}).'';
      }
      {
        assertion = badRanges == [];
        message = ''mod."${moduleName}".ingress.${rName}: port range `from` must be <= `to`.'';
      }
      {
        assertion = cfg.enable || rCfg.withoutProvider != "assert";
        message = ''mod."${moduleName}".ingress.${rName}: requires an active firewall provider (e.g. flake.nixosModules."feat/system/firewall") to enforce zone-restricted access (${lib.concatStringsSep ", " rCfg.zones}).'';
      }
    ])
    enabledIngress
  )
  ++ lib.concatLists (
    lib.mapAttrsToList (rName: rCfg: let
      unknownZones = builtins.filter (z: !(cfg.zones ? ${z})) rCfg.fromZones;
      invalidCidrs = builtins.filter (c: !(isValidCidrOrIp c)) rCfg.toCidrs;
    in [
      {
        assertion = cfg.forward.enable;
        message = ''mod."${moduleName}".forward.rules.${rName} is enabled, so mod."${moduleName}".forward.enable must also be true.'';
      }
      {
        assertion = rCfg.fromZones != [];
        message = ''mod."${moduleName}".forward.rules.${rName}.fromZones must not be empty.'';
      }
      {
        assertion = unknownZones == [];
        message = ''mod."${moduleName}".forward.rules.${rName}.fromZones: references undeclared zone(s): ${lib.concatStringsSep ", " unknownZones} (declared: ${lib.concatStringsSep ", " declaredZoneNames}).'';
      }
      {
        assertion = invalidCidrs == [];
        message = ''mod."${moduleName}".forward.rules.${rName}.toCidrs: invalid IPv4/IPv6 CIDR(s): ${lib.concatStringsSep ", " invalidCidrs}.'';
      }
    ])
    enabledForwardRules
  )
  ++ lib.concatLists (
    lib.mapAttrsToList (eName: eCfg: let
      safeId = sanitizeId eName;
      invalidUnits = builtins.filter (u: builtins.match "^.+\\.service$" u == null) eCfg.systemdUnits;
      validUnits = builtins.filter (u: builtins.match "^.+\\.service$" u != null) eCfg.systemdUnits;
      missingUnits =
        if cfg.enable && !config.boot.isContainer
        then
          builtins.filter (u: let
            svc = config.systemd.services.${lib.removeSuffix ".service" u} or {};
            svcCfg = svc.serviceConfig or {};
          in
            !((svcCfg ? ExecStart) || (svcCfg ? ExecStartPre) || (svc.script or "") != ""))
          validUnits
        else [];
      invalidTargets =
        builtins.filter (t: !(isValidTargetAddress t.address)) eCfg.allowedTargets;
    in [
      {
        assertion = !eCfg.required || cfg.enable;
        message = ''mod."${moduleName}".egress.${eName}: egress sandbox requires an active firewall provider (e.g. flake.nixosModules."feat/system/firewall").'';
      }
      {
        assertion = builtins.match "^[A-Za-z_][A-Za-z0-9_]*$" safeId != null;
        message = ''mod."${moduleName}".egress.${eName}: key '${eName}' cannot be sanitized to a valid nftables identifier.'';
      }
      {
        assertion = eCfg.systemdUnits != [] && invalidUnits == [];
        message = ''mod."${moduleName}".egress.${eName}.systemdUnits: expected non-empty list of `<name>.service` unit names${lib.optionalString (invalidUnits != []) " (invalid: ${lib.concatStringsSep ", " invalidUnits})"}.'';
      }
      {
        assertion = missingUnits == [];
        message = ''mod."${moduleName}".egress.${eName}.systemdUnits: references undefined systemd service(s): ${lib.concatStringsSep ", " missingUnits}.'';
      }
      {
        assertion = invalidTargets == [];
        message = ''mod."${moduleName}".egress.${eName}.allowedTargets: invalid address(es) (expected IPv4/IPv6 literal, CIDR, or localhost): ${lib.concatMapStringsSep ", " (t: t.address) invalidTargets}.'';
      }
    ])
    enabledEgress
  )
  ++ lib.mapAttrsToList (id: names: {
    assertion = false;
    message = ''mod."${moduleName}".egress: multiple policies map to nftables identifier '${id}': ${lib.concatStringsSep ", " names}.'';
  })
  egressIdCollisions
  ++ lib.mapAttrsToList (unit: entries: {
    assertion = false;
    message = ''mod."${moduleName}".egress: systemd unit '${unit}' is claimed by multiple egress policies: ${lib.concatMapStringsSep ", " (x: x.policy) entries}.'';
  })
  egressUnitCollisions
