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
      self.nixosModules."feat/login-manager/greetd"
      self.nixosModules."feat/greeter/tuigreet"

      self.nixosModules."feat/gaming/steam"
      self.nixosModules."feat/gaming/sunshine"
      self.nixosModules."feat/secrets"
      self.nixosModules."feat/system/audio"
      self.nixosModules."feat/system/earlyoom"
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
      openssh.enable = true;
      printing.enable = true;
      xserver = {
        videoDrivers = ["nvidia"];
        updateDbusEnvironment = true;
      };
    };
    fonts.enableDefaultPackages = true;
    time.timeZone = "America/Los_Angeles";
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings = {
        LC_ADDRESS = "en_US.UTF-8";
        LC_IDENTIFICATION = "en_US.UTF-8";
        LC_MEASUREMENT = "en_US.UTF-8";
        LC_MONETARY = "en_US.UTF-8";
        LC_NAME = "en_US.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "en_US.UTF-8";
        LC_TELEPHONE = "en_US.UTF-8";
        LC_TIME = "en_US.UTF-8";
      };
    };
  };
}
