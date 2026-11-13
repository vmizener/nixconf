# Inbound LAN/WAN port filtering and outbound UID egress sandboxing for `feat/net/caddy`.
{
  cfg,
  config,
  lib,
  pkgs,
  vhosts,
}: let
  inherit
    (vhosts)
    discoveredServices
    explicitEntries
    hasPublicVHosts
    isIpv4Literal
    isIpv6Literal
    isLoopbackHost
    parseEndpoint
    ;

  openPublic =
    if cfg.openPublicFirewall != null
    then cfg.openPublicFirewall
    else hasPublicVHosts;

  ipv4LanCidrs = builtins.filter (c: !(lib.hasInfix ":" c)) cfg.lanCidrs;
  ipv6LanCidrs = builtins.filter (c: lib.hasInfix ":" c) cfg.lanCidrs;

  mkLanAcceptRules = proto: port:
    (map (cidr: "ip saddr ${cidr} ${proto} dport ${toString port} accept") ipv4LanCidrs)
    ++ (map (cidr: "ip6 saddr ${cidr} ${proto} dport ${toString port} accept") ipv6LanCidrs);

  lanInputRules = lib.concatStringsSep "\n" (
    (mkLanAcceptRules "tcp" cfg.httpPort)
    ++ lib.optionals (!openPublic) (
      (mkLanAcceptRules "tcp" cfg.httpsPort)
      ++ (mkLanAcceptRules "udp" cfg.httpsPort)
    )
  );

  forwardAuthEp =
    if cfg.forwardAuth.enable && cfg.forwardAuth.address != null
    then parseEndpoint cfg.forwardAuth.address
    else null;

  allowedTargets =
    (
      discoveredServices
      |> builtins.filter (d: d.isLocal || d.targetIpv4 != null)
      |> map (d: {
        host =
          if d.isLocal
          then "127.0.0.1"
          else d.targetIpv4;
        inherit (d.svc) port;
        proto = "tcp";
      })
    )
    ++ (
      explicitEntries
      |> builtins.filter (e: e.upstream != null)
      |> map (e: {
        inherit (e.upstream) host port;
        proto = "tcp";
      })
    )
    ++ lib.optional (forwardAuthEp != null) {
      inherit (forwardAuthEp) host port;
      proto = "tcp";
    }
    ++ map (t: {
      host = t.address;
      inherit (t) port proto;
    })
    cfg.egressSandbox.extraAllowedTargets;

  loopbackTargetRules =
    allowedTargets
    |> builtins.filter (t: isLoopbackHost t.host)
    |> map (t: "oifname \"lo\" ${t.proto} dport ${toString t.port} accept")
    |> lib.unique;

  lanUpstreamRules =
    allowedTargets
    |> builtins.filter (t: !(isLoopbackHost t.host))
    |> lib.concatMap (
      t:
        if isIpv4Literal t.host
        then ["ip daddr ${t.host} ${t.proto} dport ${toString t.port} accept"]
        else if isIpv6Literal t.host
        then ["ip6 daddr ${t.host} ${t.proto} dport ${toString t.port} accept"]
        else []
    )
    |> lib.unique;

  formatRuleBlock = emptyComment: rules:
    if rules == []
    then "  # ${emptyComment}"
    else lib.concatMapStringsSep "\n" (r: "  ${r}") rules;

  caddySandboxRules = pkgs.replaceVars ./caddy-sandbox.nft {
    LOOPBACK_TARGET_RULES =
      formatRuleBlock "No additional local service ports configured" loopbackTargetRules;
    LAN_UPSTREAM_RULES =
      formatRuleBlock "No LAN upstream targets configured" lanUpstreamRules;
  };
in {
  networking = {
    nftables = {
      enable = lib.mkDefault true;
      tables = lib.mkIf cfg.egressSandbox.enable {
        caddy-sandbox = {
          family = "inet";
          content = ''
            include "${caddySandboxRules}"
          '';
        };
      };
    };

    firewall = {
      allowedTCPPorts = lib.optional openPublic cfg.httpsPort;
      allowedUDPPorts = lib.optional openPublic cfg.httpsPort;
      extraInputRules = lib.mkIf cfg.openLanFirewall lanInputRules;
    };
  };

  systemd.services.caddy = lib.mkIf cfg.egressSandbox.enable {
    after = ["nftables.service"];
    wants = ["nftables.service"];
    restartTriggers = [config.networking.nftables.ruleset];
    serviceConfig.NFTSet = ["user:inet:caddy-sandbox:service_uids"];
  };
}
