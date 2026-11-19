# Synthesizes the Headscale ACL, group, tagOwner, and route autoApprover policy JSON.
{
  cfg,
  lib,
  pkgs,
}:
(pkgs.formats.json {}).generate "headscale-policy.json" (
  {
    acls = [
      {
        action = "accept";
        src = ["*"];
        dst = ["*:*"];
      }
    ];
  }
  // lib.optionalAttrs (cfg.adminUsers != []) {
    groups = {
      "group:devs" = cfg.adminUsers;
    };
    tagOwners = {
      "tag:router" = ["group:devs"];
    };
  }
  // lib.optionalAttrs (cfg.autoApproveRoutes != [] && cfg.adminUsers != []) {
    autoApprovers = {
      routes = lib.genAttrs cfg.autoApproveRoutes (_: [
        "group:devs"
        "tag:router"
      ]);
    };
  }
)
