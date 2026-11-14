/*
  feat/net/tailscale

Enables the Tailscale client/router daemon using `inventory.net.vpnUrl` and
strict `nftables` forward-chain isolation on subnet routers.

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
    loginServer = flake.config.inventory.net.vpnUrl;
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

    mod.meta.imported = [moduleName];

    services.tailscale = {
      enable = true;
      inherit (cfg) authKeyFile openFirewall;
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

    # When IP forwarding is enabled on an nftables firewall host, default-drop forwarded
    # packets and explicitly permit forwarding only from `tailscale0` so future untrusted
    # tunnel interfaces cannot route packets onto the home LAN.
    networking.firewall = lib.mkIf (isRouter && config.networking.nftables.enable) {
      filterForward = lib.mkDefault true;
      extraForwardRules = ''
        iifname "${interfaceName}" accept
      '';
    };
  };
}
