/*
  users/mustadio

Dedicated disposable sandbox user for VM feature testing on `goug`
(no real-world machine account or SOPS secret dependencies).

Exposes:

- flake.nixosModules."users/mustadio@goug"
*/
{self, ...}: let
  username = "mustadio";
in {
  # @Goug (Nixos VM)
  flake.nixosModules."users/${username}@goug" = {pkgs, ...}: {
    imports = [
      self.nixosModules."feat/terminal/shell/zsh"
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
        self.homeModules."feat/system/mime"
        self.homeModules."feat/system/systools"
        self.homeModules."feat/terminal/emulator/foot"
        self.homeModules."feat/terminal/shell/zsh"
      ];
      mod."feat/desktop/shell/awww".img = ../../../assets/wallpapers/fft_agrias.jpg;
    };
  };
}
