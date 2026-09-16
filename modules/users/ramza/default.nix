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
      users.${username} = {...}: {
        imports = [
          self.homeModules."common"
          self.homeModules."feat/browser/firefox"
          self.homeModules."feat/browser/helium"
          self.homeModules."feat/desktop-manager/xfce"
          self.homeModules."feat/gaming/discord"
          self.homeModules."feat/gaming/streamlink"
          self.homeModules."feat/system/systools"
          self.homeModules."feat/tools/git"
          self.homeModules."feat/tools/kando"
          self.homeModules."feat/tools/maestral"
          self.homeModules."feat/tools/nvim"
          self.homeModules."feat/terminal/emulator/foot"
          self.homeModules."feat/terminal/shell/zsh"
        ];
      };
    };
    nixpkgs.config.allowUnfree = true;
  };
}
