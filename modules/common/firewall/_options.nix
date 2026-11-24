# Host-local packet-filter broker schema (`options.mod."common/firewall"`).
{
  activeProviders,
  cfg,
  lib,
}: let
  portRangeSubmodule = lib.types.submodule {
    options = {
      from = lib.mkOption {
        type = lib.types.port;
        description = "Inclusive start port of the range.";
      };
      to = lib.mkOption {
        type = lib.types.port;
        description = "Inclusive end port of the range.";
      };
    };
  };

  portListOption = description:
    lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      apply = lib.unique;
      inherit description;
    };

  providerSubmodule = lib.types.submodule ({name, ...}: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this firewall provider is active.";
      };
      id = lib.mkOption {
        type = lib.types.str;
        default = name;
        readOnly = true;
        description = "Identifier key of this firewall provider.";
      };
    };
  });

  zoneSubmodule = lib.types.submodule {
    options = {
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        apply = lib.unique;
        example = ["tailscale0"];
        description = "Network interfaces whose inbound traffic belongs to this zone (`iifname`).";
      };
      cidrs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        apply = lib.unique;
        example = ["192.168.86.0/24" "fd00::/8"];
        description = "IPv4 and IPv6 source addresses or CIDRs belonging to this zone (`ip/ip6 saddr`).";
      };
      any = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this zone matches unrestricted traffic from any source (`0.0.0.0/0` and `::/0`).";
      };
    };
  };

  ingressSubmodule = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this inbound firewall rule is active.";
      };
      zones = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["lan" "vpn"];
        apply = lib.unique;
        description = "Trust zone names in `mod.\"common/firewall\".zones` allowed to reach these ports.";
      };
      tcp = portListOption "Inbound TCP ports allowed from `zones`.";
      udp = portListOption "Inbound UDP ports allowed from `zones`.";
      tcpRanges = lib.mkOption {
        type = lib.types.listOf portRangeSubmodule;
        default = [];
        description = "Inbound TCP port ranges allowed from `zones`.";
      };
      udpRanges = lib.mkOption {
        type = lib.types.listOf portRangeSubmodule;
        default = [];
        description = "Inbound UDP port ranges allowed from `zones`.";
      };
      withoutProvider = lib.mkOption {
        type = lib.types.enum ["open" "closed" "assert"];
        default = "open";
        description = ''
          Fallback behavior when no `common/firewall` provider is active (`enable == false`):
          - `"open"`: Fall back to global `networking.firewall.allowed*Ports`.
          - `"closed"`: Leave ports closed in `networking.firewall`.
          - `"assert"`: Fail NixOS evaluation unless a firewall provider is imported.
        '';
      };
    };
  };

  forwardRuleSubmodule = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this forwarding rule is active.";
      };
      fromZones = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        apply = lib.unique;
        example = ["vpn"];
        description = "Source zone names in `mod.\"common/firewall\".zones` permitted to forward packets.";
      };
      toCidrs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        apply = lib.unique;
        example = ["192.168.86.0/24"];
        description = "Optional destination IPv4/IPv6 CIDRs permitted (empty allows any destination).";
      };
      proto = lib.mkOption {
        type = lib.types.enum ["any" "tcp" "udp"];
        default = "any";
        description = "Transport protocol filter when `tcp` and `udp` port lists are empty.";
      };
      tcp = portListOption "Forwarded destination TCP ports allowed.";
      udp = portListOption "Forwarded destination UDP ports allowed.";
    };
  };

  egressTargetSubmodule = lib.types.submodule {
    options = {
      address = lib.mkOption {
        type = lib.types.str;
        example = "192.168.86.138";
        description = "Destination IPv4/IPv6 literal, CIDR, or `127.0.0.1`/`::1`/`localhost`.";
      };
      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Optional destination port (`null` allows any port on `address` for `proto`).";
      };
      proto = lib.mkOption {
        type = lib.types.enum ["tcp" "udp"];
        default = "tcp";
        description = "Transport protocol allowed to `address`.";
      };
    };
  };

  egressSubmodule = lib.types.submodule ({name, ...}: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this outbound service egress sandbox is active.";
      };
      required = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to fail evaluation if enabled without an active `common/firewall` provider.";
      };
      systemdUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["${name}.service"];
        defaultText = lib.literalExpression ''["''${name}.service"]'';
        apply = lib.unique;
        description = "Systemd `.service` units confined to this egress policy via `NFTSet=`.";
      };
      allowDns = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to allow outbound DNS (`:53` TCP/UDP) over loopback.";
      };
      loopbackPorts = {
        tcp = portListOption "Additional loopback destination TCP ports allowed.";
        udp = portListOption "Additional loopback destination UDP ports allowed.";
      };
      allowPrivate = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to allow outbound connections to RFC1918, CGNAT (`100.64.0.0/10`), link-local, and ULA private ranges beyond `allowedTargets`.";
      };
      allowedTargets = lib.mkOption {
        type = lib.types.listOf egressTargetSubmodule;
        default = [];
        description = "Explicit loopback or private/LAN endpoints this service may connect to.";
      };
      internet = lib.mkOption {
        type = lib.types.enum ["none" "restricted" "full"];
        default = "none";
        description = ''
          Outbound public internet access policy (evaluated after loopback and private-network filters):
          - `"none"`: Reject all public internet egress.
          - `"restricted"`: Allow only `publicPorts.{tcp,udp}` to public destinations.
          - `"full"`: Allow outbound connections to any public internet port.
        '';
      };
      publicPorts = {
        tcp = portListOption "Outbound TCP ports allowed to public internet addresses when `internet = \"restricted\"`.";
        udp = portListOption "Outbound UDP ports allowed to public internet addresses when `internet = \"restricted\"`.";
      };
    };
  });
in {
  providers = lib.mkOption {
    type = lib.types.attrsOf providerSubmodule;
    default = {};
    description = "Registered host firewall providers (at most one may be enabled per host).";
  };
  enable = lib.mkOption {
    type = lib.types.bool;
    default = activeProviders cfg.providers != [];
    defaultText = lib.literalExpression "activeProviders != []";
    readOnly = true;
    description = "Whether a host firewall provider is active.";
  };
  provider = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = let
      active = activeProviders cfg.providers;
    in
      if active == []
      then null
      else (builtins.head active).id;
    defaultText = lib.literalExpression "activeProvider.id or null";
    readOnly = true;
    description = "Identifier of the active host firewall provider (or `null` if none is enabled).";
  };
  zones = lib.mkOption {
    type = lib.types.attrsOf zoneSubmodule;
    default = {};
    description = "Named network trust zones mapping interfaces and source CIDRs for `ingress` and `forward` rules.";
  };
  ingress = lib.mkOption {
    type = lib.types.attrsOf ingressSubmodule;
    default = {};
    description = "Declarative inbound firewall port rules scoped to `zones`.";
  };
  forward = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable default-drop packet forwarding (`filterForward`) and evaluate `forward.rules`.";
    };
    rules = lib.mkOption {
      type = lib.types.attrsOf forwardRuleSubmodule;
      default = {};
      description = "Declarative packet-forwarding allow rules between zones and destination CIDRs.";
    };
  };
  egress = lib.mkOption {
    type = lib.types.attrsOf egressSubmodule;
    default = {};
    description = "Per-service outbound `NFTSet` egress sandboxes keyed by logical policy name.";
  };
}
