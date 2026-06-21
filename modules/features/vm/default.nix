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
{ self, ... }: {
  flake.nixosModules."core" = { lib, ... }: {
    options.features.vm = {
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
    };
  };
  flake.nixosModules."feat/vm" = {
    config = {
      virtualisation.vmVariant = {
        features.vm.isVm = true;
        services.qemuGuest.enable = true;
        virtualisation = {
          memorySize = 4096; # use 4GiB memory
          cores = 3;         # use 3 cpu cores
          qemu.options = [
            "-device virtio-vga-gl"
            "-display sdl,gl=on"
          ];
        };
      };
    };
  };

  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    {
      packages =
        self.nixosConfigurations
        |> lib.filterAttrs (
          hostname: hostconf: hostconf.config.nixpkgs.hostPlatform.system == system
        )
        # Generate both VM runner and reset packages
        |> (
          configs:
          let
            vmRunners = lib.mapAttrs' (
              hostname: hostconf:
              lib.nameValuePair "vm-run-${hostname}" (
                pkgs.writeShellApplication {
                  name = "vm-run-${hostname}";
                  text = ''
                    STORAGE_DIR="${hostconf.config.features.vm.storageDir}"
                    mkdir -p "$STORAGE_DIR"
                    export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$STORAGE_DIR/${hostconf.config.networking.hostName}.qcow2}"
                    ${hostconf.config.system.build.vm}/bin/run-${hostconf.config.networking.hostName}-vm "$@"
                  '';
                }
              )
            ) configs;
            vmResetters = lib.mapAttrs' (
              hostname: hostconf:
              lib.nameValuePair "vm-reset-${hostname}" (
                pkgs.writeShellApplication {
                  name = "vm-reset-${hostname}";
                  text = ''
                    STORAGE_DIR="${hostconf.config.features.vm.storageDir}"
                    NIX_DISK_IMAGE="$STORAGE_DIR/${hostconf.config.networking.hostName}.qcow2"
                    if [ -f "$NIX_DISK_IMAGE" ]; then
                        echo "Removing $NIX_DISK_IMAGE"
                        rm "$NIX_DISK_IMAGE"
                    else
                        echo "No image found at $NIX_DISK_IMAGE"
                    fi
                  '';
                }
              )
            ) configs;
          in
          vmRunners // vmResetters
        );
    };
}
