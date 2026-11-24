/*
  feat/system/firewall

Enables kernel `nftables` host firewalling and registers the `nftables`
provider with `common/firewall` for zone-scoped ingress, packet forwarding,
and systemd `NFTSet` per-service egress sandboxing.

Exposes:

- flake.nixosModules."common/options" (options.mod."feat/system/firewall")
- flake.nixosModules."feat/system/firewall"
*/
{...}: let
  moduleName = "feat/system/firewall";
  sandboxTable = "service-sandbox";
in {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      allowPing = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to respond to inbound ICMP echo requests (`networking.firewall.allowPing`).";
      };
      logRefusedConnections = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to log refused inbound connections (`networking.firewall.logRefusedConnections`).";
      };
      logRejectedEgress = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to emit rate-limited kernel logs (`nft-egress-<name>:`) before rejecting outbound traffic in `egress` sandboxes.";
      };
    };
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    fwCfg = config.mod."common/firewall";
    compiled = import ./_rules.nix {
      inherit fwCfg lib;
      inherit (cfg) logRejectedEgress;
    };
    sandboxRulesFile = pkgs.replaceVars ./service-sandbox.nft compiled.sandboxTemplateVars;
  in {
    mod = {
      meta.imported = [moduleName];
      "common/firewall".providers.nftables = {};
    };

    networking = lib.mkIf (!config.boot.isContainer) {
      nftables = {
        enable = lib.mkDefault true;
        tables = lib.mkIf compiled.hasEgress {
          ${sandboxTable} = {
            family = "inet";
            content = ''
              include "${sandboxRulesFile}"
            '';
          };
        };
      };

      firewall = {
        enable = lib.mkDefault true;
        allowPing = lib.mkDefault cfg.allowPing;
        logRefusedConnections = lib.mkDefault cfg.logRefusedConnections;
        allowedTCPPorts = compiled.publicPorts.tcp;
        allowedUDPPorts = compiled.publicPorts.udp;
        allowedTCPPortRanges = compiled.publicPorts.tcpRanges;
        allowedUDPPortRanges = compiled.publicPorts.udpRanges;
        extraInputRules = lib.mkIf (compiled.extraInputRules != "") compiled.extraInputRules;
        filterForward = lib.mkIf fwCfg.forward.enable (lib.mkDefault true);
        extraForwardRules = lib.mkIf (compiled.extraForwardRules != "") compiled.extraForwardRules;
      };
    };

    systemd.services = lib.mkIf (!config.boot.isContainer && compiled.hasEgress) (
      lib.foldl' (
        acc: entry:
          acc
          // lib.genAttrs (map (lib.removeSuffix ".service") entry.systemdUnits) (_: {
            after = ["nftables.service"];
            wants = ["nftables.service"];
            restartTriggers = [config.systemd.services.nftables.serviceConfig.ExecStart];
            serviceConfig.NFTSet = ["user:inet:${sandboxTable}:${entry.setName}"];
          })
      ) {}
      compiled.egressEntries
    );
  };
}
