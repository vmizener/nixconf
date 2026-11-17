# Build-time domain, cookie scope, and OIDC validation assertions for `feat/net/authelia`.
{
  cfg,
  flakeNet,
  headscaleRedirectUri,
  lib,
  moduleName,
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
    assertion = cfg.domain == null || lib.hasInfix "." cfg.domain;
    message = "mod.\"${moduleName}\".domain ('${toString cfg.domain}') must be a multi-label domain name (contains '.') for Authelia session cookies.";
  }
  {
    assertion = !cfg.enableOidc || headscaleRedirectUri != null;
    message = "mod.\"${moduleName}\".enableOidc requires inventory.net.vpnUrl to be set for Headscale's callback URI.";
  }
]
