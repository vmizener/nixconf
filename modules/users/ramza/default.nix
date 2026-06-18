{ self, inputs, ... }: let
  username = "ramza";
in {
  # @Igros (Nixos)
  flake.nixosModules."users/${username}@igros" = {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    users.users.${username} = {
      isNormalUser = true;
      description = "${username}";
      extraGroups = [ "networkmanager" "wheel" ];
      initialPassword = "gobears";
    };
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.${username} = { pkgs, ... }: {
        imports = [
          self.homeModules."feat/desktop-manager/kde-plasma"
          self.homeModules."feat/shell/zsh"
          self.homeModules."feat/nvim"
        ];
        home = {
          packages = with pkgs; [
            animdl
          ];
          sessionVariables = {
            EDITOR = "nvim";
          };
          stateVersion = "25.11";
        };
      };
    };
    nixpkgs.config.allowUnfree = true;
  };

  # # Standalone Home Profile
  # flake.homeConfigurations."${username}@igros" = nhConfig {
  #   pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
  #   modules = [
  #     {
  #       programs.home-manager.enable = true;
  #       home.homeDirectory = homepath;
  #       home.sessionVariables.NH_FLAKE = "${homepath}/config";
  #       home.stateVersion = "25.11";
  #       home.username = username;
  #     }
  #     self.homeModules."feat/shell/zsh"
  #     self.homeModules."feat/nvim"
  #   ];
  # };
}
