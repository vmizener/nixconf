{
  lib,
  self,
  ...
}: {
  ################
  # Global options

  # Automatically merge homeModules, similar to nixosModules
  options.flake.homeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = {};
    description = "Home-manager modules";
  };

  # Automatically merge homeConfigurations, similar to nixosConfigurations
  options.flake.homeConfigurations = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Home-manager configurations";
  };

  # Cross-host network topology, service discovery, and DNS registry
  options.mod.net = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "lan";
      description = "Base domain for Blocky/Caddy virtual hosts (while .local is used by mDNS)";
    };
    proxyHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Hostname running the reverse proxy (Caddy) for mod.net.hosts.*.services";
    };
    hosts = lib.mkOption {
      default = {};
      description = "Per-host static IP, DNS record, and reverse-proxy service inventory";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
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
              description = "Additional DNS hostname-to-IPv4 mappings published by this host";
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
          };
        }
      );
    };

    # Readonly options (values defined in modules/net.nix)
    allDnsRecords = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Merged DNS records across mod.net.hosts and proxied services (defined in modules/net.nix)";
    };
    lib = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      readOnly = true;
      internal = true;
      description = "Helper functions for parsing and qualifying mod.net hostnames (defined in modules/net.nix)";
    };
  };

  config = let
    ################
    # Common options for both Home-Manager and NixOS modules
    commonOptions = {config, ...}: {
      options = {
        # Mutable options
        mod.imported = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          apply = lib.unique;
          description = "List of imported modules";
        };

        # Readonly options
        mod.has = lib.mkOption {
          default = name:
            if !(self.nixosModules ? ${name} || self.homeModules ? ${name})
            then throw "mod.has: unknown module '${name}'"
            else builtins.elem name config.mod.imported;
          description = "Check whether a module has been imported";
          readOnly = true;
        };
      };
    };
  in {
    ################
    # Home-Manager module options
    flake.homeModules."common/options" = {
      config,
      osConfig ? null,
      ...
    }: {
      imports = [commonOptions];
      options = {
        # Mutable options
        mod.asserts = lib.mkOption {
          type = lib.types.listOf (lib.types.enum [
            "nixosOnly" # Module is for nixos configs only
            "standaloneOnly" # Module is for standalone home-manager configs only
            "pairedNixosFeat" # Module must be paired with nixos feat import if on nixos
            "conflictsNixosFeat" # Module conflicts with nixos feature; must import only one
          ]);
          default = [];
          apply = lib.unique;
          description = "Common assertions enforced for each Home-Manager module setting them.";
        };

        mod.nixconf.path = lib.mkOption {
          type = lib.types.str;
          default =
            if osConfig != null
            then osConfig.mod.nixconf.path or "/etc/nixos"
            else "${config.xdg.configHome}/home-manager";
          description = "Absolute path to this Nix flake (outside Nix store).  Used for NH_FLAKE and out-of-store symlinks.";
        };

        # Readonly options
        mod.nixconf.link = lib.mkOption {
          default = filepath: let
            relpath = lib.removePrefix "./" (lib.path.removePrefix ./.. filepath);
          in
            config.lib.file.mkOutOfStoreSymlink "${config.mod.nixconf.path}/${relpath}";
          description = "Make a mutable symlink path to the given config source";
          readOnly = true;
        };
      };
    };

    ################
    # NixOS module options
    flake.nixosModules."common/options" = {...}: {
      imports = [commonOptions];
      options = {
        mod.nixconf.path = lib.mkOption {
          type = lib.types.str;
          default = "/etc/nixos";
          description = "Absolute path to this Nix flake (outside Nix store).  Used for NH_FLAKE.";
        };
      };
    };
  };
}
