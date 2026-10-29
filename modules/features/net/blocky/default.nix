/*
  feat/net/blocky

Enables Blocky, a fast and lightweight DNS proxy and ad-blocker for the local network.

Exposes:

- flake.nixosModules."feat/net/blocky":
*/
{...} @ flake: let
  moduleName = "feat/net/blocky";
in {
  flake.nixosModules."common/options" = {
    lib,
    pkgs,
    ...
  }: {
    options.mod.${moduleName} = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.blocky;
        description = "Blocky package to use";
      };
      dnsPort = lib.mkOption {
        type = lib.types.either lib.types.port lib.types.str;
        default = 53;
        description = "DNS listen port or address:port";
      };
      httpPort = lib.mkOption {
        type = lib.types.either lib.types.port lib.types.str;
        default = 4000;
        description = "HTTP listen port or address:port for API/DoH/metrics";
      };
      customDNS = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Additional custom DNS hostname-to-IP mappings";
      };
      enableConfigCheck = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Validate the Blocky configuration template at build time";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open the DNS and HTTP ports in the firewall";
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
    allCustomDNS = flake.config.mod.net.allDnsRecords // cfg.customDNS;

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
  in {
    mod.imported = [moduleName];

    environment.systemPackages = with pkgs; [blocky];
    services.blocky = {
      enable = true;
      inherit (cfg) package;
      # Replaced below to validate templateFile instead of services.blocky.settings
      enableConfigCheck = false;
    };

    # Overwrite default ExecStart from services.blocky to use templateFile
    systemd.services.blocky.serviceConfig.ExecStart =
      lib.mkForce "${lib.getExe cfg.package} --config ${templateFile}";

    system.checks = lib.mkIf cfg.enableConfigCheck [
      (pkgs.runCommand "check-blocky-config" {} ''
        ${lib.getExe cfg.package} --config ${templateFile} validate && touch $out
      '')
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts =
        (lib.optional (builtins.isInt cfg.dnsPort) cfg.dnsPort)
        ++ (lib.optional (builtins.isInt cfg.httpPort) cfg.httpPort);
      allowedUDPPorts = lib.optional (builtins.isInt cfg.dnsPort) cfg.dnsPort;
    };
  };
}
