{
  self,
  inputs,
  ...
}: let
  hostname = "igros";
in {
  flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules."host/${hostname}"
    ];
  };
  flake.nixosModules."host/${hostname}" = {config, ...}: {
    imports = [
      self.nixosModules."common"
      self.nixosModules."hardware/${hostname}"

      self.nixosModules."users/bao@igros"
      self.nixosModules."users/ramza@igros"

      self.nixosModules."feat/desktop-manager/xfce"
      self.nixosModules."feat/display-manager/greetd"

      self.nixosModules."feat/gaming/steam"
      self.nixosModules."feat/gaming/sunshine"
      self.nixosModules."feat/secrets"
      self.nixosModules."feat/system/audio"
      self.nixosModules."feat/system/earlyoom"
      self.nixosModules."feat/system/locale"
      self.nixosModules."feat/systools"
      self.nixosModules."feat/vm"
    ];
    system.stateVersion = "24.05";
    networking.hostName = "${hostname}";

    boot.loader = {
      grub = {
        enable = true;
        device = "nodev"; # "nodev" is used for UEFI
        efiSupport = true;
        memtest86.enable = true; # Enable Memtest86+
      };
      efi.canTouchEfiVariables = true;
    };
    nixpkgs.config.nvidia.acceptLicense = true;
    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      nvidia = {
        modesetting.enable = true;
        nvidiaSettings = true;
        # open = false;
        package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
        powerManagement.enable = false;
        powerManagement.finegrained = false;
      };
      uinput.enable = true;
    };
    services = {
      getty.autologinUser = "ramza";
      printing.enable = true;
      xserver = {
        videoDrivers = ["nvidia"];
        updateDbusEnvironment = true;
      };
    };
    fonts.enableDefaultPackages = true;
  };
}
