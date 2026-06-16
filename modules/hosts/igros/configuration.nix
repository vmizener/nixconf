{ self, inputs, ... }:
let
  hostname = "igros";
in
{
  flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules."host/${hostname}"
    ];
  };
  flake.nixosModules."host/${hostname}" = {
    imports = [
      self.nixosModules."hardware/${hostname}"

      self.nixosModules."users/bao@igros"
      self.nixosModules."users/ramza@igros"

      self.nixosModules."feat/desktop-manager/gnome"
      self.nixosModules."feat/display-manager/gdm"
      self.nixosModules."feat/secrets"
      self.nixosModules."feat/systools"
      self.nixosModules."feat/vm"

    ];
    system.stateVersion = "24.05";
    networking.hostName = "${hostname}";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    services = {
      openssh.enable = true;
      printing.enable = true;
      getty.autologinUser = "ramza";
    };
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
