/*
  feat/systools

Provides common utilities used for system administration and associated functionality.

Exposes:

- flake.nixosModules."feat/systools":
  - Installs user CLI tools
  - Enables udisks2.

- flake.homeModules."feat/systools":
  - Installs user CLI tools (deduplicated against NixOS systemPackages)
  - Configures udiskie automounting.
*/
{inputs, ...}: let
  systoolsPackages = pkgs:
    with pkgs; [
      bat
      bc
      btop
      delta
      dex
      eza
      fastfetch
      fd
      findutils
      fzf
      git
      gnumake
      gparted
      hardinfo2
      jq
      just
      killall
      libnotify
      mlocate
      nh
      pavucontrol
      pstree
      ripgrep
      smartmontools
      st
      timg
      tmux
      tree
      unzip
      usbutils
      vim
      wev
      wget
      yazi
      zip
    ];
in {
  flake.homeModules."feat/systools" = {pkgs, ...}: {
    imports = [
      inputs.nix-index-database.homeModules.nix-index
    ];
    home.packages =
      (systoolsPackages pkgs)
      ++ (with pkgs; [
        comma
      ]);
    programs.nix-index.enable = true;
    services = {
      udiskie = {
        enable = true;
        automount = true;
      };
    };
    systemd.user.startServices = "sd-switch";
  };

  flake.nixosModules."feat/systools" = {pkgs, ...}: {
    environment.systemPackages = systoolsPackages pkgs;
    services = {
      udisks2.enable = true;
    };
  };
}
