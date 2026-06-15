let
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
      killall
      libnotify
      mlocate
      nh
      pavucontrol
      pstree
      ripgrep
      smartmontools
      timg
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
  flake.homeModules."feat/systools" = {pkgs, lib, osConfig ? {}, ...}: {
    # Don't install packages already present in systemPackages
    home.packages = (
      lib.subtractLists 
      (osConfig.environment.systemPackages or [])
      (systoolsPackages pkgs)
    );
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
