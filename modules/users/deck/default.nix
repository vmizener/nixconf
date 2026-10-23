{
  config,
  inputs,
  self,
  ...
}: let
  inherit (config.mod) mkHomeUser;
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
  flake.homeModules."users/${username}@steamdeck" = mkHomeUser {
    inherit username;
    hmImports = [
      self.homeModules."feat/system/nix-user-chroot"
      self.homeModules."feat/system/systools"
      self.homeModules."feat/tools/git"
      self.homeModules."feat/tools/nvim"
    ];
    hmConfig = {
      mod."feat/system/systools".categories = ["core" "sysadmin"];
    };
  };
}
