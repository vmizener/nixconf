{
  self,
  inputs,
  ...
}: let
  username = "bao";
in {
  # @Igros (Nixos)
  flake.nixosModules."users/${username}@igros" = {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    users.users.${username} = {
      isNormalUser = true;
      description = "${username}";
      extraGroups = ["networkmanager" "wheel"];
      initialPassword = "gobears";
    };
  };
  # @Baohaus (Nixos)
  flake.nixosModules."users/${username}@baohaus" = {
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
          self.homeModules."feat/browser/helium"
          self.homeModules."feat/desktop-manager/niri"
          self.homeModules."feat/gaming/discord"
          self.homeModules."feat/gaming/streamlink"
          self.homeModules."feat/systools"
          self.homeModules."feat/terminal/emulator/foot"
          self.homeModules."feat/terminal/shell/zsh"
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
}
