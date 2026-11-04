/*
  feat/vm

Provides QEMU virtual machine runner generation for NixOS configurations.

Exposes:

- flake.nixosModules."feat/vm":
  - Enables virtualization features and associated packages (see below).

- perSystem.packages:
  - Generates `vm-run-<hostname>` package (to run the <hostname> VM).
  - Generates `vm-reset-<hostname>` package (to reset the <hostname> VM).
*/
{
  inputs,
  self,
  ...
}: let
  moduleName = "feat/vm";
in {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      isVm = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Config describes VM";
      };
      storageDir = lib.mkOption {
        type = lib.types.str;
        default = "$HOME/.local/share/nix-vm";
        description = "Directory to store VM disk images";
      };
      autologinUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "bao";
        description = "User to automatically log in on TTYs inside the VM";
      };
    };
  };
  flake.nixosModules.${moduleName} = {
    config,
    lib,
    options,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    config = {
      mod.meta.imported = [moduleName];
      virtualisation.vmVariant =
        {
          mod = {
            meta.flakePath = lib.mkVMOverride "${self}"; # mount flake store source for symlink support
            ${moduleName}.isVm = true;
          };
          services.qemuGuest.enable = true;
          services.getty.autologinUser = lib.mkIf (cfg.autologinUser != null) cfg.autologinUser;
          users.users =
            config.users.users
            |> lib.filterAttrs (_: u: u.isNormalUser)
            |> lib.mapAttrs (_: _: {
              hashedPasswordFile = lib.mkVMOverride null;
              initialPassword = lib.mkVMOverride "vm";
            });
          virtualisation = {
            memorySize = 4096; # use 4GiB memory
            cores = 3; # use 3 cpu cores
            qemu.options = [
              "-device virtio-vga-gl"
              "-display sdl,gl=on"
            ];
          };
        }
        // lib.optionalAttrs (options ? sops) {
          sops = {
            validateSopsFiles = lib.mkVMOverride false;
            secrets =
              config.sops.secrets
              |> lib.mapAttrs (_: _: {
                neededForUsers = lib.mkVMOverride false;
              });
          };
        };
    };
  };

  perSystem = {
    lib,
    pkgs,
    system,
    ...
  }: {
    packages = import ./_packages.nix {
      inherit inputs lib moduleName pkgs self system;
    };
  };
}
