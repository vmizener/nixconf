/*
  feat/net/mdns

Enables Avahi multicast DNS (mDNS) for zero-configuration `.local` hostname and service discovery.

Exposes:

- flake.nixosModules."feat/net/mdns":
*/
{...}: let
  moduleName = "feat/net/mdns";
in {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open UDP port 5353 for multicast DNS";
      };
    };
  };

  flake.nixosModules.${moduleName} = {config, ...}: let
    cfg = config.mod.${moduleName};
  in {
    mod.imported = [moduleName];
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      inherit (cfg) openFirewall;
      publish = {
        enable = true;
        addresses = true;
        userServices = true;
        workstation = true;
      };
    };
  };
}
