{
  self,
  inputs,
  ...
}: let
  username = "ramza";
in {
  # @Igros (Nixos)
  flake.nixosModules."users/${username}@igros" = {...}: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    users.users.${username} = {
      isNormalUser = true;
      description = "${username}";
      extraGroups = [
        "audio"
        "bluetooth"
        "input"
        "networkmanager"
        "video"
        "wheel"
      ];
      initialPassword = "gobears";
    };
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.${username} = {pkgs, ...}: {
        imports = [
          self.homeModules."common"
          self.homeModules."feat/browser/firefox"
          self.homeModules."feat/desktop-manager/xfce"
          self.homeModules."feat/gaming/discord"
          self.homeModules."feat/gaming/streamlink"
          self.homeModules."feat/systools"
          self.homeModules."feat/tools/git"
          self.homeModules."feat/tools/kando"
          self.homeModules."feat/tools/maestral"
          self.homeModules."feat/tools/nvim"
          self.homeModules."feat/terminal/emulator/foot"
          self.homeModules."feat/terminal/shell/zsh"
        ];
        home = {
          packages = with pkgs; [
            animdl
          ];
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
