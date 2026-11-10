/*
  users/mustadio

Dedicated disposable sandbox user for VM feature testing on `goug` (NixOS)
and `draklor` (standalone Home-Manager), with no real-world machine account
or SOPS secret dependencies.

Exposes:

- flake.nixosModules."users/mustadio@goug"
- flake.homeConfigurations."mustadio@draklor"
- flake.homeModules."users/mustadio@draklor"
*/
{
  inputs,
  self,
  ...
}: let
  username = "mustadio";
in {
  # @Goug (NixOS VM)
  flake.nixosModules."users/${username}@goug" = {pkgs, ...}: {
    imports = [
      self.nixosModules."feat/desktop/greeter/greetd"
      self.nixosModules."feat/desktop/manager/niri"
      self.nixosModules."feat/terminal/shell/zsh"

      ({...}: {
        mod."feat/desktop/greeter/greetd" = {
          autologinUser = username;
          autologinCommand = "niri-session";
        };
      })
    ];
    users.users.${username} = {
      isNormalUser = true;
      description = username;
      extraGroups = [
        "audio"
        "bluetooth"
        "input"
        "networkmanager"
        "video"
        "wheel"
      ];
      initialPassword = "vm";
      shell = pkgs.zsh;
    };
    nix.settings.trusted-users = [username];
    home-manager.users.${username} = {
      imports = [
        self.homeModules."feat/desktop/launcher/fuzzel"
        self.homeModules."feat/desktop/manager/niri"
        self.homeModules."feat/desktop/shell/awww"
        self.homeModules."feat/dev/git"
        self.homeModules."feat/system/systools"
        self.homeModules."feat/terminal/emulator/foot"
        self.homeModules."feat/terminal/shell/zsh"
      ];
      mod."feat/desktop/shell/awww".img = ../../../assets/wallpapers/fft_agrias.jpg;
    };
  };

  # @Draklor (Standalone Home-Manager VM)
  flake.homeConfigurations."${username}@draklor" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
    extraSpecialArgs = {osConfig = null;};
    modules = [
      self.homeModules."users/${username}@draklor"
    ];
  };
  flake.homeModules."users/${username}@draklor" = {
    imports = [
      self.homeModules."common"
      self.homeModules."feat/desktop/launcher/fuzzel"
      self.homeModules."feat/desktop/manager/niri"
      self.homeModules."feat/desktop/shell/awww"
      self.homeModules."feat/dev/git"
      self.homeModules."feat/system/systools"
      self.homeModules."feat/terminal/emulator/foot"
      self.homeModules."feat/terminal/shell/zsh"
      self.homeModules."feat/vm"
    ];
    home.username = username;
    programs.zsh.profileExtra = ''
      [[ -o interactive && -z $WAYLAND_DISPLAY && $TTY == /dev/tty1 ]] && exec niri-session -l
    '';
    mod = {
      "feat/desktop/shell/awww".img = ../../../assets/wallpapers/fft_agrias.jpg;
      "feat/system/systools".categories = ["core" "sysadmin" "media"];
      "feat/vm" = {
        isVm = true;
        cores = 8;
        memorySize = 16384;
      };
    };
  };
}
