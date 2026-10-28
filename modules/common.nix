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
      stateVersion = lib.mkDefault "25.11";
      homeDirectory = lib.mkOptionDefault "/home/${config.home.username}";
      sessionPath = ["${config.home.profileDirectory}/bin"];
    };
    nix =
      {
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 10d";
        };
        nixPath = ["nixpkgs=${inputs.nixpkgs}"]; # Pin <nixpkgs> lookups (e.g. nixd) to flake input
        registry.nixpkgs.flake = inputs.nixpkgs; # Pin nixpkgs# flake refs (nix run, comma) to flake input
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
    nixpkgs = lib.optionalAttrs (osConfig == null) {
      config.allowUnfree = true;
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
      inputs.home-manager.nixosModules.home-manager
      self.nixosModules."common/options"
      self.nixosModules."common/sops"
    ];
    home-manager = {
      useGlobalPkgs = lib.mkDefault true;
      useUserPackages = lib.mkDefault true;
      backupFileExtension = lib.mkDefault "backup";
      sharedModules = [
        self.homeModules."common"
      ];
    };
    nix = {
      channel.enable = false; # Disable imperative channels and ~/.nix-defexpr NIX_PATH hijacking
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      nixPath = ["nixpkgs=${inputs.nixpkgs}"]; # Pin <nixpkgs> lookups (e.g. nixd) to flake input
      optimise.automatic = true;
      registry.nixpkgs.flake = inputs.nixpkgs; # Pin nixpkgs# flake refs (nix run, comma) to flake input
      settings.experimental-features = [
        "flakes"
        "nix-command"
        "pipe-operators"
      ];
    };
    nixpkgs.config.allowUnfree = true;
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
