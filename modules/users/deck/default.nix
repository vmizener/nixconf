{
  inputs,
  self,
  ...
}: let
  username = "deck";
  pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
in {
  # @SteamDeck (Home-Manager)
  flake.homeConfigurations."${username}@steamdeck" = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      self.homeModules."users/${username}@steamdeck"
    ];
  };
  flake.homeModules."users/${username}@steamdeck" = {
    imports = [
      self.homeModules."common"
      self.homeModules."feat/terminal/shell/zsh"
      self.homeModules."feat/system/nix-user-chroot"
      self.homeModules."feat/system/systools"
      self.homeModules."feat/tools/git"
      self.homeModules."feat/tools/nvim"
    ];
    home.username = username;
    mod."feat/system/systools".categories = ["core" "sysadmin"];
  };
}
