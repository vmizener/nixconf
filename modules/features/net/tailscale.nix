/*
  feat/net/tailscale

Enables the Tailscale client/router daemon using `site.net.vpnUrl` and
registers `vpn` zone ingress and subnet-router forwarding with `common/firewall`.

Exposes:

- flake.nixosModules."feat/net/tailscale":
*/
{...} @ flake: let
  moduleName = "feat/net/tailscale";
  interfaceName = "tailscale0";
in {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      role = lib.mkOption {
        type = lib.types.enum ["client" "router" "both"];
        default = "client";
        description = ''
          Routing role for this Tailscale node:
          - `"client"`: Standard peer accepting advertised subnet routes.
          - `"router"`: Subnet router enabling kernel IP forwarding (does not accept peer routes).
          - `"both"`: Both advertises and accepts routes.
        '';
      };
      advertiseRoutes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["192.168.86.0/24"];
        description = "Subnet CIDRs advertised by this node when acting as a subnet router";
      };
      authKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional runtime secret file containing a pre-auth key for unattended node registration";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open Tailscale's WireGuard UDP port in the firewall";
      };
    };
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
    loginServer = flake.config.site.net.vpnUrl;
    isRouter = cfg.role == "router" || cfg.role == "both";
    acceptRoutes = cfg.role != "router";
    routingFeatures =
      if cfg.role == "router"
      then "server"
      else cfg.role;
    routesArg = "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}";
    acceptRoutesArg = "--accept-routes=${lib.boolToString acceptRoutes}";
  in {
    assertions = [
      {
        assertion = cfg.advertiseRoutes == [] || isRouter;
        message = "mod.\"${moduleName}\": advertiseRoutes is non-empty, so role must be \"router\" or \"both\" (currently \"${cfg.role}\").";
      }
    ];

    mod = {
      meta.imported = [moduleName];
      "common/site/net".ports.tailscale.udp = [config.services.tailscale.port];
      "common/firewall" = {
        zones.vpn.interfaces = [interfaceName];
        ingress.tailscale = {
          enable = cfg.openFirewall;
          zones = ["public"];
          udp = [config.services.tailscale.port];
        };
        forward = {
          enable = lib.mkIf isRouter true;
          rules.tailscale = {
            enable = isRouter;
            fromZones = ["vpn"];
            toCidrs = cfg.advertiseRoutes;
          };
        };
      };
    };

    services.tailscale = {
      enable = true;
      inherit (cfg) authKeyFile;
      openFirewall = false;
      inherit interfaceName;
      useRoutingFeatures = routingFeatures;
      disableUpstreamLogging = true;
      authKeyParameters = lib.optionalAttrs (cfg.authKeyFile != null && loginServer != null) {
        baseURL = loginServer;
      };
      extraUpFlags =
        lib.optional (loginServer != null) "--login-server=${loginServer}"
        ++ [acceptRoutesArg]
        ++ lib.optional (cfg.advertiseRoutes != []) routesArg;
      extraSetFlags =
        [acceptRoutesArg]
        ++ lib.optional (cfg.advertiseRoutes != []) routesArg;
    };
  };
}
