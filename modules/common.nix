{
  inputs,
  self,
  ...
}: {
  flake.homeModules."common" = {
    config,
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: {
    imports = [
      self.homeModules."common/options"
      self.homeModules."common/sops"
    ];
    home = {
      stateVersion = "25.11";
      sessionPath = ["${config.home.profileDirectory}/bin"];
    };
    nix =
      {
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 10d";
        };
        nixPath = ["nixpkgs=${inputs.nixpkgs}"];
      }
      // lib.optionalAttrs (osConfig == null) {
        package = lib.mkDefault pkgs.nix;
        settings = {
          experimental-features = [
            "flakes"
            "nix-command"
            "pipe-operators"
          ];
          max-jobs = lib.mkDefault "auto";
        };
      };
    programs.home-manager.enable = true; # Home-Manager installs and manages itself
    programs.nh = {
      enable = lib.mkDefault true;
      flake = lib.mkDefault config.mod.nixconf.path;
    };
    systemd.user.startServices = "sd-switch"; # Reload system units on config change
    xdg.enable = true; # Enable XDG directory management
    xdg.portal = {
      enable = true;
      config = {
        common.default = ["gtk"];
      };
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
      xdgOpenUsePortal = true;
    };
  };
  flake.nixosModules."common" = {
    config,
    lib,
    ...
  }: {
    imports = [
      self.nixosModules."common/options"
      self.nixosModules."common/sops"
    ];
    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      optimise.automatic = true;
      settings.experimental-features = [
        "flakes"
        "nix-command"
        "pipe-operators"
      ];
    };
    environment.pathsToLink = [
      # Needed by xdg.portal in the case no desktop is imported
      "/share/applications"
      "/share/xdg-desktop-portal"
    ];
    programs.nh = {
      enable = lib.mkDefault true;
      flake = lib.mkDefault config.mod.nixconf.path;
    };
    services.openssh.enable = true;
  };
}
