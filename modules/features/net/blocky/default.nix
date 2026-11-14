/*
  feat/net/blocky

Enables Blocky, a fast and lightweight DNS proxy and ad-blocker for the local network.

Exposes:

- flake.nixosModules."feat/net/blocky":
*/
{...} @ flake: let
  moduleName = "feat/net/blocky";
in {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      dnsPort = lib.mkOption {
        type = lib.types.either lib.types.port lib.types.str;
        default = 53;
        description = "DNS listen port or address:port";
      };
      httpPort = lib.mkOption {
        type = lib.types.either lib.types.port lib.types.str;
        default = "127.0.0.1:4000";
        description = "HTTP listen port or address:port for API/DoH/metrics";
      };
      customDNS = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Additional custom DNS hostname-to-IP mappings";
      };
      openDnsFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open an integer `dnsPort` (TCP/UDP) in the firewall";
      };
      openHttpFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to open an integer `httpPort` (TCP) in the firewall";
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
    package = pkgs.blocky;
    allCustomDNS = flake.config.inventory.net.allDnsRecords // cfg.customDNS;

    customDnsBlock =
      if allCustomDNS == {}
      then "# No customDNS mappings configured"
      else
        "customDNS:\n  mapping:\n"
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: ip: "    ${name}: ${ip}") allCustomDNS
        );

    templateFile = pkgs.replaceVars ./config.yaml {
      DNS_PORT = toString cfg.dnsPort;
      HTTP_PORT = toString cfg.httpPort;
      CUSTOM_DNS_BLOCK = customDnsBlock;
    };

    checkScript = pkgs.replaceVars ./check-config.sh {
      BLOCKY_BIN = lib.getExe package;
      CONFIG_FILE = templateFile;
    };
  in {
    mod.meta.imported = [moduleName];

    environment.systemPackages = [package];
    services.blocky = {
      enable = true;
      inherit package;
      # Replaced below to validate templateFile instead of services.blocky.settings
      enableConfigCheck = false;
    };

    # Overwrite default ExecStart from services.blocky to use templateFile
    systemd.services.blocky.serviceConfig.ExecStart =
      lib.mkForce "${lib.getExe package} --config ${templateFile}";

    system.checks = [
      (pkgs.runCommand "check-blocky-config" {} ''
        ${pkgs.runtimeShell} ${checkScript} "$out"
      '')
    ];

    networking.firewall = {
      allowedTCPPorts =
        (lib.optional (cfg.openDnsFirewall && builtins.isInt cfg.dnsPort) cfg.dnsPort)
        ++ (lib.optional (cfg.openHttpFirewall && builtins.isInt cfg.httpPort) cfg.httpPort);
      allowedUDPPorts =
        lib.optional (cfg.openDnsFirewall && builtins.isInt cfg.dnsPort) cfg.dnsPort;
    };
  };
}
