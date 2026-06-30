{
  inputs,
  self,
  ...
}: {
  flake.homeModules."common" = {config, ...}: {
    imports = [
      self.homeModules."common/options"
    ];
    home = {
      stateVersion = "25.11";
      sessionPath = ["${config.home.profileDirectory}/bin"];
    };
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    programs.home-manager.enable = true; # Home-Manager installs and manages itself
    systemd.user.startServices = "sd-switch"; # Reload system units on config change
    xdg = {
      enable = true; # Enable XDG directory management
      mime.enable = true; # Enable MIME-type support
    };
  };

  flake.nixosModules."common" = {...}: {
    imports = [
      self.nixosModules."common/options"
    ];
    nix.settings.experimental-features = [
      "flakes"
      "nix-command"
      "pipe-operators"
    ];
  };
}
