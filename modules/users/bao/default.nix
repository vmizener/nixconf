{
  config,
  self,
  ...
}: let
  inherit (config.mod) mkNixosUser;
  username = "bao";
  userConfig = {
    initialPassword = "gobears";
  };
in {
  # @Igros (Nixos)
  flake.nixosModules."users/${username}@igros" = mkNixosUser {
    inherit username userConfig;
    hmImports = [
      self.homeModules."feat/browser/firefox"
      self.homeModules."feat/tools/git"
      self.homeModules."feat/tools/nvim"
    ];
  };
  # @Baohaus (Nixos)
  flake.nixosModules."users/${username}@baohaus" = mkNixosUser {
    inherit username userConfig;
    extraGroups = [
      "audio"
      "bluetooth"
      "input"
      "video"
    ];
    nixosImports = [
      self.nixosModules."feat/tools/input-actions"
    ];
    hmImports = [
      self.homeModules."feat/ai/pi"
      self.homeModules."feat/browser/helium"
      self.homeModules."feat/desktop-manager/niri"
      self.homeModules."feat/desktop-shell/dms"
      self.homeModules."feat/file-manager/thunar"
      self.homeModules."feat/gaming/discord"
      self.homeModules."feat/gaming/harbourmasters"
      self.homeModules."feat/gaming/retroarch"
      self.homeModules."feat/gaming/streamlink"
      self.homeModules."feat/system/mime"
      self.homeModules."feat/system/systools"
      self.homeModules."feat/system/theme"
      self.homeModules."feat/tools/ani-cli"
      self.homeModules."feat/tools/awww"
      self.homeModules."feat/tools/evince"
      self.homeModules."feat/tools/git"
      self.homeModules."feat/tools/input-actions"
      self.homeModules."feat/tools/kanshi"
      self.homeModules."feat/tools/maestral"
      self.homeModules."feat/tools/nvim"
      self.homeModules."feat/tools/spotify"
      self.homeModules."feat/tools/torrra"
      self.homeModules."feat/terminal/emulator/foot"
      self.homeModules."feat/terminal/emulator/ghostty"
    ];
    hmConfig = {config, ...}: {
      mod."feat/tools/awww".img =
        ../../../assets/wallpapers/girl_leaving_apartment.png;
      mod."feat/gaming/harbourmasters" = {
        shipofharkinian = {
          enable = true;
          gamepaths = [
            "${config.home.homeDirectory}/Downloads/Emulation/Games/oot.v64"
          ];
        };
        ghostship = {
          enable = true;
          gamepaths = [
            "${config.home.homeDirectory}/Downloads/Emulation/Games/sm64.z64"
          ];
        };
      };
    };
  };
  # @Zeltennia (Nixos)
  flake.nixosModules."users/${username}@zeltennia" = mkNixosUser {
    inherit username userConfig;
    nixosConfig.nix.settings.trusted-users = [username];
    hmImports = [
      self.homeModules."feat/tools/git"
    ];
  };
}
