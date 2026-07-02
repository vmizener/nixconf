{
  self,
  inputs,
  ...
}: let
  username = "bao";
in {
  # @Igros (Nixos)
  flake.nixosModules."users/${username}@igros" = {...}: {
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
  flake.nixosModules."users/${username}@baohaus" = {...}: {
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
          self.homeModules."feat/browser/helium"
          self.homeModules."feat/desktop-manager/niri"
          self.homeModules."feat/desktop-shell/dms"
          self.homeModules."feat/gaming/discord"
          self.homeModules."feat/gaming/streamlink"
          self.homeModules."feat/system/mime"
          self.homeModules."feat/system/theme"
          self.homeModules."feat/systools"
          self.homeModules."feat/tools/ani-cli"
          self.homeModules."feat/tools/awww"
          self.homeModules."feat/tools/git"
          self.homeModules."feat/tools/kanshi"
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
}
