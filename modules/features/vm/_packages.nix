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
  nixglBin =
    if nixglPkg != null
    then "${nixglPkg}/bin/nixGLIntel"
    else "";

  mkVmRunner = hostname: hostconf: let
    cfg = hostconf.config.mod.${moduleName};
    hostName = hostconf.config.networking.hostName;
  in
    lib.nameValuePair "vm-run-${hostname}" (pkgs.writeShellApplication {
      name = "vm-run-${hostname}";
      text =
        ''
          STORAGE_DIR="${cfg.storageDir}"
          mkdir -p "$STORAGE_DIR"
          export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$STORAGE_DIR/${hostName}.qcow2}"

          if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
            echo "warning: /dev/kvm is not accessible; QEMU will fall back to slow TCG emulation" >&2
          fi

          wrapper=()
        ''
        + lib.optionalString (cfg.graphics && cfg.gl) ''
          has_host_gpu=0
          for node in /dev/dri/renderD*; do
            if [ -r "$node" ] && [ -w "$node" ]; then
              has_host_gpu=1
              break
            fi
          done

          if [ "$has_host_gpu" -eq 0 ]; then
            export LIBGL_ALWAYS_SOFTWARE=1
            export LP_NUM_THREADS="''${LP_NUM_THREADS:-4}"
          fi

          nixgl_fallback="${nixglBin}"
          if [ ! -d /run/opengl-driver ]; then
            if command -v nixGL >/dev/null 2>&1; then
              wrapper=(nixGL)
            elif [ -n "$nixgl_fallback" ]; then
              wrapper=("$nixgl_fallback")
            fi
          fi
        ''
        + lib.optionalString (cfg.graphics && !cfg.gl) ''
          export SDL_RENDER_DRIVER="''${SDL_RENDER_DRIVER:-software}"
        ''
        + ''

          exec "''${wrapper[@]}" ${hostconf.config.system.build.vm}/bin/run-${hostName}-vm "$@"
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
