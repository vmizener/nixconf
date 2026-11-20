/*
  feat/gaming/sunshine

Sunshine self-hosted game streaming server.

Exposes:

- flake.nixosModules."feat/gaming/sunshine":
*/
{...}: let
  moduleName = "feat/gaming/sunshine";
in {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open Sunshine's streaming and web UI ports in the firewall";
      };
    };
  };

  flake.nixosModules.${moduleName} = {config, ...}: let
    cfg = config.mod.${moduleName};
  in {
    mod.meta.imported = [moduleName];
    # Upstream `services.sunshine` manages `hardware.uinput`, udev rules, and dynamic
    # TCP/UDP port offsets from `settings.port`—avoid mirroring them manually.
    services.sunshine = {
      enable = true;
      autoStart = true; # optional: starts Sunshine automatically on login
      capSysAdmin = true;
      inherit (cfg) openFirewall;
    };
  };
}
