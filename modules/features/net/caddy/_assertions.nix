# Build-time validation & safety assertions for `feat/net/caddy`.
{
  cfg,
  currentHost,
  flakeNet,
  lib,
  moduleName,
  vhosts,
}: let
  inherit
    (vhosts)
    discoveredServices
    explicitCollisions
    isIpv4Literal
    isIpv6Literal
    isLoopbackHost
    parseEndpoint
    ;

  isValidSandboxHost = h: isLoopbackHost h || isIpv4Literal h || isIpv6Literal h;

  forwardAuthEp =
    if cfg.forwardAuth.address != null
    then parseEndpoint cfg.forwardAuth.address
    else null;

  publicSsoServices =
    builtins.filter (d: d.svc.visibility == "public" && d.svc.auth == "sso") discoveredServices;

  remoteDiscoveredHostsWithoutIpv4 =
    discoveredServices
    |> builtins.filter (d: !d.isLocal && d.targetIpv4 == null)
    |> map (d: d.targetHostName)
    |> lib.unique;

  invalidExtraTargets =
    builtins.filter (t: !(isValidSandboxHost t.address)) cfg.egressSandbox.extraAllowedTargets;
in
  [
    {
      assertion = flakeNet.proxyHost == currentHost;
      message = "Host '${currentHost}' imports ${moduleName}; set inventory.net.proxyHost = \"${currentHost}\" so service DNS records point to this proxy.";
    }
    {
      assertion = !cfg.forwardAuth.enable || cfg.forwardAuth.address != null;
      message = "mod.\"${moduleName}\".forwardAuth.address must be set when forwardAuth.enable is true.";
    }
    {
      assertion =
        !cfg.acme.enable
        || (
          flakeNet.publicDomain
          != null
          && cfg.acme.email != null
          && cfg.acme.dnsProvider != null
          && cfg.acme.environmentFile != null
        );
      message = "mod.\"${moduleName}\".acme.enable requires inventory.net.publicDomain plus acme.{email,dnsProvider,environmentFile} to be set.";
    }
  ]
  ++ lib.mapAttrsToList (key: entries: {
    assertion = false;
    message =
      "mod.\"${moduleName}\".virtualHosts: multiple keys qualify to '${key}': "
      + lib.concatMapStringsSep ", " (e: "'${e.rawKey}'") entries;
  })
  explicitCollisions
  ++ map (d: {
    assertion = cfg.forwardAuth.enable && cfg.forwardAuth.address != null;
    message = "inventory.net.hosts.${d.source}: public service requires auth = \"sso\", but mod.\"${moduleName}\".forwardAuth is not enabled.";
  })
  publicSsoServices
  ++ lib.optionals cfg.egressSandbox.enable (
    (map (host: {
        assertion = false;
        message = "inventory.net.hosts.${host}: static ipv4 must be set when exposing proxied services with mod.\"${moduleName}\".egressSandbox.enable = true.";
      })
      remoteDiscoveredHostsWithoutIpv4)
    ++ lib.optional (cfg.forwardAuth.enable && cfg.forwardAuth.address != null) {
      assertion = forwardAuthEp != null && isValidSandboxHost forwardAuthEp.host;
      message = "mod.\"${moduleName}\".forwardAuth.address '${toString cfg.forwardAuth.address}' must be a literal IP:port or localhost:port when egressSandbox is enabled.";
    }
    ++ map (t: {
      assertion = false;
      message = "mod.\"${moduleName}\".egressSandbox.extraAllowedTargets: address '${t.address}' must be an IPv4/IPv6 literal or localhost.";
    })
    invalidExtraTargets
  )
