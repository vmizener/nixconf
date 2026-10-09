/*
  feat/net

Shared networking options, static IP assignment, and service/DNS registries for NixOS hosts.

Exposes:

- flake.nixosModules."common/options":
  - `mod.net.domain`: Base domain for local virtual hosts (default: "lan")
  - `mod.net.interface`: Network interface for static IP configuration
  - `mod.net.ipv4`: Static IPv4 address for the host
  - `mod.net.prefixLength`: Subnet prefix length (default: 24)
  - `mod.net.gateway`: Default gateway IPv4 address
  - `mod.net.nameservers`: DNS nameservers for the host
  - `mod.net.dnsRecords`: Host-published DNS records (`<fqdn> = "<ipv4>"`)
  - `mod.net.services`: Host-published services for reverse proxying
  - `mod.net.hosts`: Read-only attrset of `<hostname> = "<ipv4>"` across all `nixosConfigurations`
  - `mod.net.allDnsRecords`: Read-only merged `dnsRecords` across all `nixosConfigurations`

- flake.nixosModules."common":
  - Configures static IPv4 networking when `mod.net.ipv4` is set
  - Registers `<hostname>.<domain> = <ipv4>` into `mod.net.dnsRecords`
*/
{self, ...}: {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.net = {
      # Mutable options
      domain = lib.mkOption {
        type = lib.types.str;
        default = "lan";
        description = "Base domain for Blocky/Caddy virtual hosts (while .local is used by mDNS)";
      };
      interface = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Network interface name for static IPv4 assignment (e.g. 'eno1', 'end0', 'eth0')";
      };
      ipv4 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Static LAN IPv4 address assigned to this host";
      };
      prefixLength = lib.mkOption {
        type = lib.types.ints.between 1 32;
        default = 24;
        description = "Subnet prefix length for the static IPv4 address";
      };
      gateway = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default IPv4 gateway address";
      };
      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "DNS nameservers to configure on this host";
      };
      dnsRecords = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "DNS hostname-to-IPv4 mappings published by this host";
      };
      services = lib.mkOption {
        default = {};
        description = "Network services exposed by this host for reverse proxying";
        type = lib.types.attrsOf (
          lib.types.submodule ({name, ...}: {
            options = {
              port = lib.mkOption {
                type = lib.types.port;
                description = "Port the service listens on";
              };
              subdomain = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Subdomain or hostname to expose on the reverse proxy";
              };
              protocol = lib.mkOption {
                type = lib.types.enum ["http" "https"];
                default = "http";
                description = "Upstream protocol used by the service";
              };
            };
          })
        );
      };

      # Readonly options
      hosts = lib.mkOption {
        readOnly = true;
        description = "Map of hostnames to static IPv4 addresses across all nixosConfigurations";
        default =
          self.nixosConfigurations
          |> lib.filterAttrs (_: hostconf: hostconf.config.mod.net.ipv4 != null)
          |> lib.mapAttrs' (
            _: hostconf:
              lib.nameValuePair
              hostconf.config.networking.hostName
              hostconf.config.mod.net.ipv4
          );
      };
      allDnsRecords = lib.mkOption {
        readOnly = true;
        description = "Merged DNS records published across all nixosConfigurations";
        default =
          lib.foldlAttrs (
            acc: _: hostconf:
              acc // hostconf.config.mod.net.dnsRecords
          ) {}
          self.nixosConfigurations;
      };
    };
  };

  flake.nixosModules."common" = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.net;
    isVm = config.mod."feat/vm".isVm or false;
  in {
    config = lib.mkMerge [
      (lib.mkIf (cfg.ipv4 != null) {
        mod.net.dnsRecords."${config.networking.hostName}.${cfg.domain}" = lib.mkDefault cfg.ipv4;
      })
      (lib.mkIf (cfg.ipv4 != null && !isVm) {
        assertions = [
          {
            assertion = cfg.interface != null;
            message = "mod.net.interface must be set when mod.net.ipv4 is specified.";
          }
        ];

        networking = {
          interfaces.${cfg.interface} = {
            useDHCP = false;
            ipv4.addresses = [
              {
                address = cfg.ipv4;
                inherit (cfg) prefixLength;
              }
            ];
          };
          defaultGateway = lib.mkIf (cfg.gateway != null) cfg.gateway;
          nameservers = lib.mkIf (cfg.nameservers != []) cfg.nameservers;
        };
      })
    ];
  };
}
