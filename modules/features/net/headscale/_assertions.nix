# Build-time domain, MagicDNS, VPN URL, ACL, OIDC, and Web UI assertions for `feat/net/headscale`.
{
  cfg,
  flakeNet,
  lib,
  magicDnsDomain,
  moduleName,
  oidcIssuerUrl,
  serverDomain,
  tagMatches,
}: [
  {
    assertion = cfg.domain != null && flakeNet.domains ? ${cfg.domain};
    message =
      if cfg.domainTag != null && cfg.domain == null
      then
        if tagMatches == []
        then "mod.\"${moduleName}\": domainTag '${cfg.domainTag}' matched no domains in inventory.net.domains."
        else "mod.\"${moduleName}\": domainTag '${cfg.domainTag}' is ambiguous (matched: ${lib.concatStringsSep ", " tagMatches}); set `domain` explicitly."
      else "mod.\"${moduleName}\".domain ('${toString cfg.domain}') must reference a declared domain in inventory.net.domains.";
  }
  {
    assertion = serverDomain == null || serverDomain != magicDnsDomain;
    message = "mod.\"${moduleName}\": subdomain '${cfg.subdomain}' collides with MagicDNS domain 'tail'.";
  }
  {
    assertion =
      flakeNet.vpnUrl
      == null
      || serverDomain == null
      || lib.removeSuffix "/" flakeNet.vpnUrl == "https://${serverDomain}";
    message = "mod.\"${moduleName}\": server URL ('https://${toString serverDomain}') disagrees with inventory.net.vpnUrl ('${toString flakeNet.vpnUrl}').";
  }
  {
    assertion = cfg.autoApproveRoutes == [] || cfg.adminUsers != [];
    message = "mod.\"${moduleName}\": adminUsers (e.g. [\"user@example.com\"]) must be set when autoApproveRoutes is non-empty.";
  }
  {
    assertion = !cfg.enableOidc || oidcIssuerUrl != null;
    message = "mod.\"${moduleName}\".enableOidc requires mod.\"common/net\".oidc.issuerUrl to be set (e.g. via `feat/net/authelia` with a configured domain on this host).";
  }
  {
    assertion = !cfg.webUi.enable || (cfg.webUi.domain != null && flakeNet.domains ? ${cfg.webUi.domain});
    message = "mod.\"${moduleName}\".webUi.domain ('${toString cfg.webUi.domain}') must reference a declared domain in inventory.net.domains.";
  }
]
