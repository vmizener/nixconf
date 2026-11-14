{
  self,
  inputs,
  ...
}: let
  hostname = "baohaus";
in {
  inventory.net.hosts.${hostname} = {
    interface = "enp3s0";
    ipv4 = "192.168.86.138";
    gateway = "192.168.86.1";
    nameservers = ["192.168.86.1"];
  };

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

      # self.nixosModules."feat/ai/ollama"
      self.nixosModules."feat/desktop/greeter/ly"
      self.nixosModules."feat/desktop/manager/niri"
      self.nixosModules."feat/gaming/steam"
      self.nixosModules."feat/gaming/sunshine"
      self.nixosModules."feat/io/audio"
      self.nixosModules."feat/io/ckb-next"
      self.nixosModules."feat/io/ditto"
      self.nixosModules."feat/media/services/jackett"
      self.nixosModules."feat/net/tailscale"
      self.nixosModules."feat/system/earlyoom"
      self.nixosModules."feat/system/keyring"
      self.nixosModules."feat/system/locale"
      self.nixosModules."feat/system/systools"
      self.nixosModules."feat/system/theme"
      self.nixosModules."feat/terminal/mux/float"
      self.nixosModules."feat/vm"
    ];
    mod = {
      # "feat/ai/ollama" = {
      #   package = pkgs.ollama-rocm;
      #   loadModels = ["qwen3.5:9b"];
      # };
      "feat/gaming/steam".enableExtest = true;
      "feat/vm".autologinUser = "bao";
    };

    system.stateVersion = "24.05";
    networking.hostName = "${hostname}";
    users.mutableUsers = false;

    boot = {
      binfmt.emulatedSystems = ["aarch64-linux"]; # Allow building aarch64-linux
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
      printing.enable = true;
    };
    fonts.enableDefaultPackages = true;
  };
}
