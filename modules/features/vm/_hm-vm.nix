# Generate QEMU VM runner (`vm-run-<host>`) and reset (`vm-reset-<host>`) packages
# for standalone `homeConfigurations` matching `system` that import `feat/vm`.
{
  lib,
  mkBinScript,
  mkResetPkg,
  moduleName,
  nixglBin,
  pkgs,
  self,
  system,
}: let
  boolToStr = b:
    if b
    then "1"
    else "0";

  inferHostName = confKey: hmConf: let
    explicit = hmConf.config.mod.${moduleName}.hostName;
    parts = lib.splitString "@" confKey;
  in
    if explicit != null
    then explicit
    else if builtins.length parts > 1
    then lib.last parts
    else confKey;

  mkVmHmConf = hmConf: let
    vmOverride = {options, ...}: {
      config =
        {
          mod = {
            meta.flakePath = lib.mkVMOverride "${self}";
            ${moduleName}.isVm = lib.mkVMOverride true;
          };
        }
        // lib.optionalAttrs (options ? sops) {
          sops.validateSopsFiles = lib.mkVMOverride false;
        };
    };
  in
    if hmConf ? extendModules
    then hmConf.extendModules {modules = [vmOverride];}
    else hmConf;

  mkHmVmPackages = confKey: rawHmConf: let
    hostName = inferHostName confKey rawHmConf;
    hmCfg = (mkVmHmConf rawHmConf).config;
    cfg = hmCfg.mod.${moduleName};

    username = hmCfg.home.username;
    profileDir = hmCfg.home.profileDirectory;
    activationPkg = hmCfg.home.activationPackage;
    nixPkg = hmCfg.nix.package;
    useUserChroot = hmCfg.mod.meta.has "feat/system/nix-user-chroot";
    shellHandler = hmCfg.mod."common/handlers".get.shell;

    baseImage =
      if builtins.isPath cfg.image || builtins.isString cfg.image
      then cfg.image
      else pkgs.fetchurl {inherit (cfg.image) url hash;};

    closure = pkgs.closureInfo {
      rootPaths =
        [activationPkg nixPkg "${self}"]
        ++ lib.optional useUserChroot pkgs.nix-user-chroot;
    };

    activateGuestScript = pkgs.replaceVars ./scripts/activate-guest.sh {
      USE_USER_CHROOT = boolToStr useUserChroot;
      USER_NAME = username;
      HOME_DIR = hmCfg.home.homeDirectory;
      NIX_DIR =
        if useUserChroot
        then hmCfg.mod."feat/system/nix-user-chroot".nixDir
        else "";
      CHROOT_BIN_STORE_REL =
        if useUserChroot
        then lib.removePrefix "/nix/store/" "${pkgs.nix-user-chroot}/bin/nix-user-chroot"
        else "";
      NIX_BIN_DIR = "${nixPkg}/bin";
      ACTIVATION_PKG = "${activationPkg}";
      FLAKE_SRC = "${self}";
      DESIRED_SHELL =
        if !useUserChroot && shellHandler != null
        then builtins.head shellHandler.cmd
        else "";
      GUEST_PACKAGES = lib.concatStringsSep " " cfg.guestPackages;
    };

    runtimeDir =
      pkgs.runCommand "hm-vm-runtime-${hostName}" {
        nativeBuildInputs = [pkgs.shellcheck];
      } ''
        mkdir -p "$out"
        ln -s "${closure}/registration" "$out/registration"
        install -Dm755 "${activateGuestScript}" "$out/activate-guest.sh"
        shellcheck -s bash "$out/activate-guest.sh"
      '';

    fallbackProfileScript = lib.optionalString (!useUserChroot && shellHandler == null) ''
      if [ "$(id -un 2>/dev/null || true)" = "${username}" ]; then
        # shellcheck disable=SC1091
        [ -f "${profileDir}/etc/profile.d/nix.sh" ] && . "${profileDir}/etc/profile.d/nix.sh"
        # shellcheck disable=SC1091
        [ -f "${profileDir}/etc/profile.d/hm-session-vars.sh" ] && . "${profileDir}/etc/profile.d/hm-session-vars.sh"
        export PATH="${profileDir}/bin:$PATH"
      fi
    '';

    seedIso = import ./_seed-iso.nix {
      inherit fallbackProfileScript hostName lib pkgs system username;
      inherit (cfg) autologin;
    };

    machineArgs =
      if system == "aarch64-linux"
      then ["-machine" "virt" "-bios" "${pkgs.OVMF.fd}/FV/QEMU_EFI.fd"]
      else ["-machine" "q35"];

    qemuStaticArgs =
      machineArgs
      ++ [
        "-m"
        (toString cfg.memorySize)
        "-smp"
        (toString cfg.cores)
        "-netdev"
        "user,id=net0"
        "-device"
        "virtio-net-pci,netdev=net0"
        "-device"
        "virtio-rng-pci"
        "-usb"
        "-device"
        "usb-tablet"
        "-drive"
        "file=${seedIso},format=raw,if=virtio,readonly=on"
        "-virtfs"
        "local,path=/nix/store,security_model=none,mount_tag=host-nix-store,readonly=on"
        "-virtfs"
        "local,path=${runtimeDir},security_model=none,mount_tag=hm-vm,readonly=on"
      ];

    displayArgs = let
      vgaDevice =
        if cfg.gl
        then "virtio-vga-gl"
        else "virtio-vga";
      resOpts =
        lib.optionalString (cfg.resolution != null)
        ",edid=on,xres=${toString cfg.resolution.width},yres=${toString cfg.resolution.height}";
      sdlOpts =
        if cfg.gl
        then "sdl,gl=on"
        else "sdl";
    in
      lib.optionals cfg.graphics [
        "-vga"
        "none"
        "-device"
        "${vgaDevice}${resOpts}"
        "-display"
        sdlOpts
        "-serial"
        "mon:stdio"
      ];

    runnerPkg = mkBinScript "vm-run-${hostName}" ./scripts/vm-run.sh {
      MODE = "hm";
      HOST_NAME = hostName;
      STORAGE_DIR = cfg.storageDir;
      GRAPHICS = boolToStr cfg.graphics;
      GL = boolToStr cfg.gl;
      NIXGL_BIN = nixglBin;
      NIXOS_VM_BIN = "";
      QEMU_BIN = "${pkgs.qemu_kvm}/bin/qemu-kvm";
      QEMU_IMG_BIN = "${pkgs.qemu_kvm}/bin/qemu-img";
      BASE_IMAGE = "${baseImage}";
      DISK_SIZE = cfg.diskSize;
      QEMU_ARGS_FILE = "${pkgs.writeText "hm-vm-args-${hostName}" (lib.concatLines qemuStaticArgs)}";
      DISPLAY_ARGS_FILE = "${pkgs.writeText "hm-vm-display-args-${hostName}" (lib.concatLines displayArgs)}";
    };

    resetterPkg = mkResetPkg {
      name = "vm-reset-${hostName}";
      inherit hostName;
      inherit (cfg) storageDir;
    };
  in {
    inherit hostName;
    packages = {
      "vm-run-${hostName}" = runnerPkg;
      "vm-reset-${hostName}" = resetterPkg;
    };
  };

  hmVmConfs =
    self.homeConfigurations
    |> lib.filterAttrs (
      _: hmConf:
        hmConf.pkgs.stdenv.hostPlatform.system
        == system
        && ((hmConf.config.mod.meta or {}).has or (_: false)) moduleName
    );

  builtHmVms = lib.mapAttrsToList mkHmVmPackages hmVmConfs;
  duplicateHosts =
    map (v: v.hostName) builtHmVms
    |> builtins.groupBy (h: h)
    |> lib.filterAttrs (_: g: builtins.length g > 1)
    |> builtins.attrNames;
in
  if duplicateHosts != []
  then throw "${moduleName}: duplicate standalone Home-Manager VM hostName(s): ${lib.concatStringsSep ", " duplicateHosts}"
  else lib.foldl' (acc: v: acc // v.packages) {} builtHmVms
