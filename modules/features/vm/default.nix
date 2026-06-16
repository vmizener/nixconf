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
  flake.nixosModules."feat/vm" = { lib, config, ... }: {
    options.features.vm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable VM runner generation";
      };
      storageDir = lib.mkOption {
        type = lib.types.str;
        default = "$HOME/.local/share/nix-vm";
        description = "Directory to store VM disk images";
      };
    };
    config = lib.mkIf config.features.vm.enable {
      virtualisation.vmVariant = {
        boot.kernelModules = [ "vkms" ];
        environment.variables = {
          LIBGL_ALWAYS_SOFTWARE = "1";
          WLR_NO_HARDWARE_CURSORS = "1";
          WLR_RENDERER = "pixman";
          WLR_RENDERER_ALLOW_SOFTWARE = "1";
        };
        virtualisation = {
          memorySize = 2048; # use 2GiB memory
          cores = 3;         # use 3 cpu cores
          qemu.options = [
            "-vga virtio"
            "-display gtk,gl=on"
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
          hostname: hostconf:
          # Must enable the vm feature (enabled by importing module)
          (lib.hasAttrByPath [ "features" "vm" "enable" ] hostconf.options)
          && hostconf.config.features.vm.enable
          # ... and use the current "perSystem" system
          && hostconf.config.nixpkgs.hostPlatform.system == system
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
