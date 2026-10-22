{
  config,
  self,
  ...
}: let
  inherit (config.mod) mkNixosUser;
  username = "ramza";
  userConfig = {
    initialPassword = "gobears";
  };
in {
  # @Igros (Nixos)
  flake.nixosModules."users/${username}@igros" = mkNixosUser {
    inherit username userConfig;
    extraGroups = [
      "audio"
      "bluetooth"
      "input"
      "video"
    ];
    hmImports = [
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
    ];
  };
}
