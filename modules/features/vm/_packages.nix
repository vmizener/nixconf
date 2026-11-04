# Generate VM runner (`vm-run-<host>`) and reset (`vm-reset-<host>`) packages
# for every nixosConfiguration matching `system` that imports `feat/vm`.
{
  inputs,
  lib,
  moduleName,
  pkgs,
  self,
  system,
}: let
  nixglPkg = inputs.nixgl.packages.${system}.nixGLIntel or null;

  mkVmRunner = hostname: hostconf:
    lib.nameValuePair "vm-run-${hostname}" (pkgs.writeShellApplication {
      name = "vm-run-${hostname}";
      text = ''
        STORAGE_DIR="${hostconf.config.mod.${moduleName}.storageDir}"
        mkdir -p "$STORAGE_DIR"
        export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$STORAGE_DIR/${hostconf.config.networking.hostName}.qcow2}"

        wrapper=()
        if [ ! -d /run/opengl-driver ]; then
          if command -v nixGL >/dev/null 2>&1; then
            wrapper=(nixGL)
        ${lib.optionalString (nixglPkg != null) ''
          else
            wrapper=("${nixglPkg}/bin/nixGLIntel")
        ''}  fi
        fi

        exec "''${wrapper[@]}" ${hostconf.config.system.build.vm}/bin/run-${hostconf.config.networking.hostName}-vm "$@"
      '';
    });

  mkVmResetter = hostname: hostconf:
    lib.nameValuePair "vm-reset-${hostname}" (pkgs.writeShellApplication {
      name = "vm-reset-${hostname}";
      text = ''
        STORAGE_DIR="${hostconf.config.mod.${moduleName}.storageDir}"
        NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$STORAGE_DIR/${hostconf.config.networking.hostName}.qcow2}"
        if [ -f "$NIX_DISK_IMAGE" ]; then
            echo "Removing $NIX_DISK_IMAGE"
            rm "$NIX_DISK_IMAGE"
        else
            echo "No image found at $NIX_DISK_IMAGE"
        fi
      '';
    });

  vmHosts =
    self.nixosConfigurations
    |> lib.filterAttrs (
      _: hostconf:
        hostconf.config.nixpkgs.hostPlatform.system
        == system
        && ((hostconf.config.mod.meta or {}).has or (_: false)) moduleName
    );
in
  (lib.mapAttrs' mkVmRunner vmHosts) // (lib.mapAttrs' mkVmResetter vmHosts)
