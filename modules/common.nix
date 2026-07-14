{
  inputs,
  self,
  ...
}: {
  flake.homeModules."common" = {config, pkgs, ...}: {
    imports = [
      self.homeModules."common/options"
    ];
    home = {
      stateVersion = "25.11";
      sessionPath = ["${config.home.profileDirectory}/bin"];
    };
    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 10d";
      };
      nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    };
    programs.home-manager.enable = true; # Home-Manager installs and manages itself
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
  flake.nixosModules."common" = {...}: {
    imports = [
      self.nixosModules."common/options"
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
    services.openssh.enable = true;
  };
}
