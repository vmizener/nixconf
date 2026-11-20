{
  inputs,
  self,
  ...
}: let
  moduleName = "common";

  commonPackages = pkgs:
    with pkgs; [
      git # VCS for managing flake repository
      handlr-regex # XDG MIME and desktop-entry handler (https://github.com/Anomalocaridid/handlr-regex)
      jq # JSON processor used by flake scripts
      just # Command runner for repo recipes
      wget # Downloader used by bootstrap scripts
      xdg-utils # Standard XDG desktop integration utilities
    ];
in {
  flake.homeModules.${moduleName} = {
    config,
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: {
    imports = [
      self.homeModules."common/handlers"
      self.homeModules."common/keyring"
      self.homeModules."common/options"
      self.homeModules."common/sops"
      self.homeModules."common/site/ssh"
    ];
    mod.meta.imported = [moduleName];
    home = {
      stateVersion = lib.mkDefault "25.11";
      homeDirectory = lib.mkOptionDefault "/home/${config.home.username}";
      sessionPath = ["${config.home.profileDirectory}/bin"];
      sessionVariables.NIXCONF_FLAKE = lib.mkDefault config.mod.meta.nixconfPath;
      packages = lib.mkIf (osConfig == null || !(osConfig.mod.meta.has moduleName)) (
        commonPackages pkgs
      );
    };
    nix =
      {
        nixPath = ["nixpkgs=${inputs.nixpkgs}"]; # Pin <nixpkgs> lookups (e.g. nixd) to flake input
        registry.nixpkgs.flake = inputs.nixpkgs; # Pin nixpkgs# flake refs (nix run, comma) to flake input
      }
      // lib.optionalAttrs (osConfig == null) {
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 10d";
        };
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
    targets.genericLinux = lib.optionalAttrs (osConfig == null) {
      enable = lib.mkDefault true;
      nixGL.packages = lib.mkDefault inputs.nixgl.packages;
    };
    programs.home-manager.enable = true; # Home-Manager installs and manages itself
    programs.nh = {
      enable = lib.mkDefault true;
      flake = lib.mkDefault config.mod.meta.flakePath;
    };
    systemd.user.startServices = "sd-switch"; # Reload system units on config change
    xdg.enable = true; # Enable XDG directory management
  };
  flake.nixosModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
      self.nixosModules."common/handlers"
      self.nixosModules."common/keyring"
      self.nixosModules."common/options"
      self.nixosModules."common/site/net"
      self.nixosModules."common/site/ssh"
      self.nixosModules."common/sops"
    ];
    mod.meta.imported = [moduleName];
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
    environment = {
      systemPackages = commonPackages pkgs;
      sessionVariables = lib.mkIf (config.mod.meta.nixconfPath != null) {
        NIXCONF_FLAKE = lib.mkDefault config.mod.meta.nixconfPath;
      };
      pathsToLink = [
        # Needed by xdg.portal in the case no desktop is imported
        "/share/applications"
        "/share/xdg-desktop-portal"
      ];
    };
    programs.nh = {
      enable = lib.mkDefault true;
      flake = lib.mkDefault config.mod.meta.flakePath;
    };
    xdg.portal.xdgOpenUsePortal = lib.mkDefault true;
  };
}
