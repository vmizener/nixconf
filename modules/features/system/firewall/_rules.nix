# Compiles `common/firewall` zone ingress, forwarding, and `NFTSet` egress policies into `nftables` rules.
{
  fwCfg,
  lib,
  logRejectedEgress,
}: let
  isLoopback = s: builtins.elem s ["localhost" "127.0.0.1" "::1"];
  isIpv6 = s: lib.hasInfix ":" s;
  sanitizeId = name: builtins.replaceStrings ["-" "."] ["_" "_"] name;

  mergeIntervals = intervals: let
    sorted =
      builtins.sort (
        a: b: a.from < b.from || (a.from == b.from && a.to < b.to)
      )
      intervals;
  in
    lib.foldl' (
      acc: cur:
        if acc == []
        then [cur]
        else let
          prev = lib.last acc;
          init = lib.init acc;
        in
          if cur.from <= prev.to + 1
          then
            init
            ++ [
              {
                inherit (prev) from;
                to = lib.max prev.to cur.to;
              }
            ]
          else acc ++ [cur]
    ) []
    sorted;

  formatInterval = r:
    if r.from == r.to
    then toString r.from
    else "${toString r.from}-${toString r.to}";

  formatDport = proto: ports: ranges: let
    merged = mergeIntervals (
      map (p: {
        from = p;
        to = p;
      })
      ports
      ++ ranges
    );
  in
    if merged == []
    then null
    else if builtins.length merged == 1
    then "${proto} dport ${formatInterval (builtins.head merged)}"
    else "${proto} dport { ${lib.concatMapStringsSep ", " formatInterval merged} }";

  formatIifname = ifaces:
    if ifaces == []
    then null
    else if builtins.length ifaces == 1
    then ''iifname "${builtins.head ifaces}"''
    else ''iifname { ${lib.concatMapStringsSep ", " (i: ''"${i}"'') ifaces} }'';

  formatSrcCidr = cidr:
    if cidr == "0.0.0.0/0"
    then {
      expr = "meta nfproto ipv4";
      family = "ipv4";
    }
    else if cidr == "::/0"
    then {
      expr = "meta nfproto ipv6";
      family = "ipv6";
    }
    else if isIpv6 cidr
    then {
      expr = "ip6 saddr ${cidr}";
      family = "ipv6";
    }
    else {
      expr = "ip saddr ${cidr}";
      family = "ipv4";
    };

  formatDstCidr = cidr:
    if cidr == "0.0.0.0/0"
    then {
      expr = "meta nfproto ipv4";
      family = "ipv4";
      isWildcard = true;
    }
    else if cidr == "::/0"
    then {
      expr = "meta nfproto ipv6";
      family = "ipv6";
      isWildcard = true;
    }
    else if isIpv6 cidr
    then {
      expr = "ip6 daddr ${cidr}";
      family = "ipv6";
      isWildcard = false;
    }
    else {
      expr = "ip daddr ${cidr}";
      family = "ipv4";
      isWildcard = false;
    };

  enabledIngress =
    fwCfg.ingress
    |> builtins.attrValues
    |> builtins.filter (r: r.enable);

  isPublicRule = r:
    builtins.any (z: (fwCfg.zones.${z} or {}).any or false) r.zones;

  publicRules = builtins.filter isPublicRule enabledIngress;
  scopedRules = builtins.filter (r: !(isPublicRule r)) enabledIngress;

  zoneInputRules =
    lib.concatLists (
      lib.mapAttrsToList (zName: zCfg: let
        matching = builtins.filter (r: builtins.elem zName r.zones) scopedRules;
        dportExprs =
          [
            (formatDport "tcp" (lib.concatMap (r: r.tcp) matching) (lib.concatMap (r: r.tcpRanges) matching))
            (formatDport "udp" (lib.concatMap (r: r.udp) matching) (lib.concatMap (r: r.udpRanges) matching))
          ]
          |> builtins.filter (x: x != null);
        ifaceExpr = formatIifname zCfg.interfaces;
      in
        if zCfg.any || matching == [] || dportExprs == []
        then []
        else
          lib.optionals (ifaceExpr != null) (
            map (dp: "${ifaceExpr} ${dp} accept") dportExprs
          )
          ++ lib.concatMap (cidr: let
            src = formatSrcCidr cidr;
          in
            map (dp: "${src.expr} ${dp} accept") dportExprs)
          zCfg.cidrs)
      fwCfg.zones
    )
    |> lib.unique;

  forwardRules = lib.optionals fwCfg.forward.enable (
    fwCfg.forward.rules
    |> lib.filterAttrs (_: r: r.enable)
    |> lib.mapAttrsToList (_: r: let
      zones = map (z: fwCfg.zones.${z}) r.fromZones;
      hasAnyZone = builtins.any (z: z.any) zones;
      allIfaces = lib.unique (lib.concatMap (z: z.interfaces) zones);
      allCidrs = lib.unique (lib.concatMap (z: z.cidrs) zones);
      srcMatchers =
        if hasAnyZone
        then [
          {
            expr = "";
            family = "any";
          }
        ]
        else
          lib.optional (allIfaces != []) {
            expr = formatIifname allIfaces;
            family = "any";
          }
          ++ map formatSrcCidr allCidrs;
      dstMatchers =
        if r.toCidrs == []
        then [
          {
            expr = "";
            family = "any";
            isWildcard = false;
          }
        ]
        else map formatDstCidr r.toCidrs;
      l4Exprs =
        if r.tcp == [] && r.udp == []
        then
          if r.proto == "any"
          then [""]
          else ["meta l4proto ${r.proto}"]
        else
          builtins.filter (x: x != null) [
            (formatDport "tcp" r.tcp [])
            (formatDport "udp" r.udp [])
          ];
    in
      lib.concatMap (
        src:
          lib.concatMap (
            dst:
              if src.family != "any" && dst.family != "any" && src.family != dst.family
              then []
              else let
                dstToken =
                  if dst.isWildcard && src.family == dst.family
                  then ""
                  else dst.expr;
              in
                map (
                  l4:
                    [src.expr dstToken l4 "accept"]
                    |> builtins.filter (s: s != "")
                    |> lib.concatStringsSep " "
                )
                l4Exprs
          )
          dstMatchers
      )
      srcMatchers)
    |> lib.concatLists
    |> lib.unique
  );

  enabledEgress = lib.filterAttrs (_: e: e.enable) fwCfg.egress;

  mkEgressEntry = eName: eCfg: let
    safeId = sanitizeId eName;
    setName = "uids_${safeId}";
    chainName = "egress_${safeId}";
    logPrefix = ''limit rate 5/minute log prefix "nft-egress-${eName}: "'';

    loTargets = builtins.filter (t: isLoopback t.address) eCfg.allowedTargets;
    netTargets = builtins.filter (t: !(isLoopback t.address)) eCfg.allowedTargets;

    loWildcardProtos =
      loTargets
      |> builtins.filter (t: t.port == null)
      |> map (t: t.proto)
      |> lib.unique;

    collectLoPorts = proto: extraPorts:
      if builtins.elem proto loWildcardProtos
      then []
      else
        lib.unique (
          lib.optional eCfg.allowDns 53
          ++ extraPorts
          ++ (
            loTargets
            |> builtins.filter (t: t.proto == proto && t.port != null)
            |> map (t: t.port)
          )
        );

    loTcpExpr = formatDport "tcp" (collectLoPorts "tcp" eCfg.loopbackPorts.tcp) [];
    loUdpExpr = formatDport "udp" (collectLoPorts "udp" eCfg.loopbackPorts.udp) [];

    loRules =
      map (p: ''oifname "lo" meta l4proto ${p} accept'') loWildcardProtos
      ++ lib.optional (loTcpExpr != null) ''oifname "lo" ${loTcpExpr} accept''
      ++ lib.optional (loUdpExpr != null) ''oifname "lo" ${loUdpExpr} accept''
      ++ lib.optional logRejectedEgress ''oifname "lo" ${logPrefix}''
      ++ [''oifname "lo" reject with icmpx type admin-prohibited''];

    lanTargetRules =
      netTargets
      |> map (t: let
        addrMatch =
          if isIpv6 t.address
          then "ip6 daddr ${t.address}"
          else "ip daddr ${t.address}";
        portMatch =
          if t.port != null
          then "${t.proto} dport ${toString t.port}"
          else "meta l4proto ${t.proto}";
      in "${addrMatch} ${portMatch} accept")
      |> lib.unique;

    privateBlockRules = lib.optionals (!eCfg.allowPrivate) (
      lib.optional logRejectedEgress "ip daddr @private_ipv4 ${logPrefix}"
      ++ ["ip daddr @private_ipv4 reject with icmpx type admin-prohibited"]
      ++ lib.optional logRejectedEgress "ip6 daddr @private_ipv6 ${logPrefix}"
      ++ ["ip6 daddr @private_ipv6 reject with icmpx type admin-prohibited"]
    );

    pubTcpExpr = formatDport "tcp" eCfg.publicPorts.tcp [];
    pubUdpExpr = formatDport "udp" eCfg.publicPorts.udp [];

    internetRules =
      if eCfg.internet == "full"
      then ["accept"]
      else
        lib.optionals (eCfg.internet == "restricted") (
          lib.optional (pubTcpExpr != null) "${pubTcpExpr} accept"
          ++ lib.optional (pubUdpExpr != null) "${pubUdpExpr} accept"
        )
        ++ lib.optional logRejectedEgress logPrefix
        ++ ["reject with icmpx type admin-prohibited"];

    bodyLines =
      ["ct state established,related accept"]
      ++ loRules
      ++ lanTargetRules
      ++ privateBlockRules
      ++ internetRules;
  in {
    inherit setName;
    inherit (eCfg) systemdUnits;
    setBlock = ''
      set ${setName} {
        typeof meta skuid
      }
    '';
    chainBlock = ''
      chain ${chainName} {
      ${lib.concatMapStringsSep "\n" (l: "  ${l}") bodyLines}
      }
    '';
    jumpRule = "  meta skuid @${setName} jump ${chainName}";
  };

  egressEntries = lib.mapAttrsToList mkEgressEntry enabledEgress;
in {
  inherit egressEntries;
  hasEgress = egressEntries != [];

  publicPorts = {
    tcp = lib.unique (lib.concatMap (r: r.tcp) publicRules);
    udp = lib.unique (lib.concatMap (r: r.udp) publicRules);
    tcpRanges = lib.concatMap (r: r.tcpRanges) publicRules;
    udpRanges = lib.concatMap (r: r.udpRanges) publicRules;
  };

  extraInputRules = lib.concatStringsSep "\n" zoneInputRules;
  extraForwardRules = lib.concatStringsSep "\n" forwardRules;

  sandboxTemplateVars = {
    SANDBOX_SETS = lib.concatStringsSep "\n" (map (e: lib.removeSuffix "\n" e.setBlock) egressEntries);
    SANDBOX_CHAINS = lib.concatStringsSep "\n\n" (map (e: lib.removeSuffix "\n" e.chainBlock) egressEntries);
    SANDBOX_JUMPS = lib.concatStringsSep "\n" (map (e: e.jumpRule) egressEntries);
  };
}
