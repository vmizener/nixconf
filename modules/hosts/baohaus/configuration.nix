{
  self,
  inputs,
  ...
}: let
  hostname = "baohaus";
in {
  flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules."host/${hostname}"
    ];
  };
  flake.nixosModules."host/${hostname}" = {pkgs, ...}: {
    imports = [
      self.nixosModules."common"
      self.nixosModules."hardware/${hostname}"

      self.nixosModules."users/bao@baohaus"

      self.nixosModules."feat/desktop-manager/niri"
      self.nixosModules."feat/display-manager/ly"

      self.nixosModules."feat/gaming/steam"
      self.nixosModules."feat/gaming/sunshine"
      self.nixosModules."feat/secrets"
      self.nixosModules."feat/system/audio"
      self.nixosModules."feat/system/earlyoom"
      self.nixosModules."feat/system/locale"
      self.nixosModules."feat/system/theme"
      self.nixosModules."feat/systools"
      self.nixosModules."feat/tools/ckb-next"
      self.nixosModules."feat/tools/ditto"
      self.nixosModules."feat/tools/float"
      self.nixosModules."feat/tools/jackett"
      self.nixosModules."feat/vm"
    ];
    features.steam.enableExtest = true;

    system.stateVersion = "24.05";
    networking.hostName = "${hostname}";

    boot = {
      loader.grub = {
        enable = true;
        device = "/dev/sda";
        useOSProber = true;
        memtest86.enable = true; # Enable Memtest86+
      };
      kernelPackages = pkgs.linuxPackages_latest;
    };
    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      uinput.enable = true;
    };
    services = {
      getty.autologinUser = "bao";
      printing.enable = true;
    };
    fonts.enableDefaultPackages = true;
  };
}
