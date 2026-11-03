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
      self.homeModules."feat/dev/git"
      self.homeModules."feat/dev/nvim"
      self.homeModules."feat/system/nix-user-chroot"
      self.homeModules."feat/system/systools"
      self.homeModules."feat/terminal/shell/zsh"
    ];
    home.username = username;
    mod."feat/system/systools".categories = ["core" "sysadmin"];
  };
}
