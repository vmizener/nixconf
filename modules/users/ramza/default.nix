{self, ...}: let
  username = "ramza";
in {
  # @Igros (Nixos)
  flake.nixosModules."users/${username}@igros" = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules."feat/terminal/shell/zsh"
    ];
    sops.secrets."passwords/${username}".neededForUsers = true;
    users.users.${username} = {
      isNormalUser = true;
      description = username;
      extraGroups = [
        "audio"
        "bluetooth"
        "input"
        "networkmanager"
        "video"
        "wheel"
      ];
      hashedPasswordFile = config.sops.secrets."passwords/${username}".path;
      shell = pkgs.zsh;
    };
    home-manager.users.${username}.imports = [
      self.homeModules."feat/desktop/browser/firefox"
      self.homeModules."feat/desktop/manager/xfce"
      self.homeModules."feat/dev/git"
      self.homeModules."feat/dev/nvim"
      self.homeModules."feat/gaming/discord"
      self.homeModules."feat/media/playback/streamlink"
      self.homeModules."feat/sync/maestral"
      self.homeModules."feat/system/systools"
      self.homeModules."feat/terminal/emulator/ghostty"
      self.homeModules."feat/terminal/shell/zsh"
    ];
  };
}
