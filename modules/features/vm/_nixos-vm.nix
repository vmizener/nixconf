# Generate VM runner (`vm-run-<host>`) and reset (`vm-reset-<host>`) packages
# for `nixosConfigurations` matching `system` that import `feat/vm`.
{
  lib,
  mkBinScript,
  mkResetPkg,
  moduleName,
  nixglBin,
  self,
  system,
}: let
  boolToStr = b:
    if b
    then "1"
    else "0";

  mkNixosVmRunner = hostname: hostconf: let
    cfg = hostconf.config.mod.${moduleName};
    hostName = hostconf.config.networking.hostName;
  in
    lib.nameValuePair "vm-run-${hostname}" (mkBinScript "vm-run-${hostname}" ./scripts/vm-run.sh {
      MODE = "nixos";
      HOST_NAME = hostName;
      STORAGE_DIR = cfg.storageDir;
      GRAPHICS = boolToStr cfg.graphics;
      GL = boolToStr cfg.gl;
      NIXGL_BIN = nixglBin;
      NIXOS_VM_BIN = "${hostconf.config.system.build.vm}/bin/run-${hostName}-vm";
      QEMU_BIN = "";
      QEMU_IMG_BIN = "";
      BASE_IMAGE = "";
      DISK_SIZE = "";
      QEMU_ARGS_FILE = "";
      DISPLAY_ARGS_FILE = "";
    });

  mkNixosVmResetter = hostname: hostconf:
    lib.nameValuePair "vm-reset-${hostname}" (mkResetPkg {
      name = "vm-reset-${hostname}";
      inherit (hostconf.config.networking) hostName;
      inherit (hostconf.config.mod.${moduleName}) storageDir;
    });

  nixosVmHosts =
    self.nixosConfigurations
    |> lib.filterAttrs (
      _: hostconf:
        hostconf.config.nixpkgs.hostPlatform.system
        == system
        && ((hostconf.config.mod.meta or {}).has or (_: false)) moduleName
    );
in
  (lib.mapAttrs' mkNixosVmRunner nixosVmHosts)
  // (lib.mapAttrs' mkNixosVmResetter nixosVmHosts)
