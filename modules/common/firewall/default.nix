/*
  common/firewall

Shared NixOS packet-filter broker (`common/firewall`), decoupling trust-zone
ingress rules, packet forwarding, and systemd `NFTSet` per-service egress
sandboxing from concrete firewall providers (e.g. `feat/system/firewall`).

Exposes:

- flake.nixosModules."common/options" (options.mod."common/firewall")
- flake.nixosModules."common/firewall"
*/
{lib, ...}: let
  moduleName = "common/firewall";

  activeProviders = providers:
    providers
    |> builtins.attrValues
    |> builtins.filter (p: p.enable);
in {
  flake.nixosModules."common/options" = {config, ...}: {
    options.mod.${moduleName} = import ./_options.nix {
      inherit activeProviders lib;
      cfg = config.mod.${moduleName};
    };
  };

  flake.nixosModules.${moduleName} = {config, ...}: let
    cfg = config.mod.${moduleName};
    fallbackIngress =
      cfg.ingress
      |> builtins.attrValues
      |> builtins.filter (
        r:
          r.enable
          && (builtins.any (z: (cfg.zones.${z} or {}).any or false) r.zones || r.withoutProvider == "open")
      );
  in {
    mod = {
      meta.imported = [moduleName];
      ${moduleName}.zones = {
        public.any = lib.mkDefault true;
        lan = {};
        vpn = {};
        proxy = {};
      };
    };

    # Graceful fallback when no provider (e.g. `feat/system/firewall`) is imported:
    # map `"public"` and `withoutProvider = "open"` rules onto upstream `networking.firewall`.
    networking.firewall = lib.mkIf (!cfg.enable) {
      allowedTCPPorts = lib.unique (lib.concatMap (r: r.tcp) fallbackIngress);
      allowedUDPPorts = lib.unique (lib.concatMap (r: r.udp) fallbackIngress);
      allowedTCPPortRanges = lib.concatMap (r: r.tcpRanges) fallbackIngress;
      allowedUDPPortRanges = lib.concatMap (r: r.udpRanges) fallbackIngress;
    };

    assertions = import ./_assertions.nix {
      inherit activeProviders cfg config lib moduleName;
    };
  };
}
