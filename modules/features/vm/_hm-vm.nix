# Generate QEMU VM runner (`vm:run-<host>`) and reset (`vm:reset-<host>`) packages
# for standalone `homeConfigurations` matching `system` that import `feat/vm`.
{
  lib,
  mkBinScript,
  mkResetPkg,
  moduleName,
  nixconfSrc,
  nixglBin,
  pkgs,
  qemu,
  self,
  system,
}: let
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
          mod.meta = {
            isVm = lib.mkVMOverride true;
            flakePath = lib.mkVMOverride "${self}";
            nixconfPath = lib.mkVMOverride nixconfSrc;
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
    activationPkg = hmCfg.home.activationPackage;
    nixPkg = hmCfg.nix.package;
    useUserChroot = hmCfg.mod.meta.has "feat/system/nix-user-chroot";
    shellHandler = hmCfg.mod."common/handlers".get.shell;

    baseImage =
      if cfg.image == null
      then builtins.seq activationPkg (throw "${moduleName}: mod.\"${moduleName}\".image must be set")
      else if builtins.isPath cfg.image || builtins.isString cfg.image
      then cfg.image
      else pkgs.fetchurl {inherit (cfg.image) url hash;};

    runtimeDir = let
      closure = pkgs.closureInfo {
        rootPaths =
          lib.unique [activationPkg nixPkg "${self}" nixconfSrc]
          ++ lib.optional useUserChroot pkgs.nix-user-chroot;
      };
      activateGuestScript = pkgs.replaceVars ./scripts/activate-guest.sh {
        USE_USER_CHROOT = qemu.boolToStr useUserChroot;
        USER_NAME = username;
        HOME_DIR = hmCfg.home.homeDirectory;
        NIX_DIR =
          if useUserChroot
          then dirOf hmCfg.home.homeDirectory
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
    in
      pkgs.runCommand "hm-vm-runtime-${hostName}" {
        nativeBuildInputs = [pkgs.shellcheck];
      } ''
        mkdir -p "$out"
        ln -s "${closure}/registration" "$out/registration"
        install -Dm755 "${activateGuestScript}" "$out/activate-guest.sh"
        shellcheck -s bash "$out/activate-guest.sh"
      '';

    seedIso = import ./_seed-iso.nix {
      inherit hostName lib pkgs system username;
      inherit (cfg) autologin;
      fallbackProfileFile =
        if !useUserChroot && shellHandler == null
        then
          pkgs.replaceVars ./scripts/guest-profile.sh {
            USER_NAME = username;
            PROFILE_DIR = hmCfg.home.profileDirectory;
          }
        else null;
    };

    qemuStaticArgs = qemu.mkHmStaticArgs {
      inherit cfg pkgs runtimeDir seedIso system;
    };

    displayArgs = qemu.mkDisplayArgs {
      inherit cfg;
      serialStdio = true;
    };
  in {
    inherit hostName;
    packages = {
      "vm:run-${hostName}" = mkBinScript "vm-run-${hostName}" ./scripts/vm-run.sh {
        MODE = "hm";
        HOST_NAME = hostName;
        STORAGE_DIR = cfg.storageDir;
        GRAPHICS = qemu.boolToStr cfg.graphics;
        GL = qemu.boolToStr cfg.gl;
        NIXGL_BIN = nixglBin;
        NIXOS_VM_BIN = "";
        QEMU_BIN = "${pkgs.qemu_kvm}/bin/qemu-kvm";
        QEMU_IMG_BIN = "${pkgs.qemu_kvm}/bin/qemu-img";
        BASE_IMAGE = "${baseImage}";
        DISK_SIZE = "${toString cfg.diskSize}M";
        QEMU_ARGS_FILE = "${pkgs.writeText "hm-vm-args-${hostName}" (lib.concatLines qemuStaticArgs)}";
        DISPLAY_ARGS_FILE = "${pkgs.writeText "hm-vm-display-args-${hostName}" (lib.concatLines displayArgs)}";
      };
      "vm:reset-${hostName}" = mkResetPkg {
        name = "vm-reset-${hostName}";
        inherit hostName;
        inherit (cfg) storageDir;
      };
    };
  };

  builtHmVms =
    self.homeConfigurations
    |> lib.filterAttrs (
      _: hmConf:
        hmConf.pkgs.stdenv.hostPlatform.system
        == system
        && ((hmConf.config.mod.meta or {}).has or (_: false)) moduleName
    )
    |> lib.mapAttrsToList mkHmVmPackages;

  duplicateHosts =
    map (v: v.hostName) builtHmVms
    |> builtins.groupBy (h: h)
    |> lib.filterAttrs (_: g: builtins.length g > 1)
    |> builtins.attrNames;
in
  if duplicateHosts != []
  then throw "${moduleName}: duplicate standalone Home-Manager VM hostName(s): ${lib.concatStringsSep ", " duplicateHosts}"
  else lib.foldl' (acc: v: acc // v.packages) {} builtHmVms
