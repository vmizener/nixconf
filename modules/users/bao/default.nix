{self, ...}: let
  username = "bao";
in {
  # @Igros (Nixos)
  flake.nixosModules."users/${username}@igros" = {pkgs, ...}: {
    imports = [
      self.nixosModules."feat/terminal/shell/zsh"
    ];
    users.users.${username} = {
      isNormalUser = true;
      description = username;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      initialPassword = "gobears";
      shell = pkgs.zsh;
    };
    home-manager.users.${username}.imports = [
      self.homeModules."feat/desktop/browser/firefox"
      self.homeModules."feat/dev/git"
      self.homeModules."feat/dev/nvim"
      self.homeModules."feat/terminal/shell/zsh"
    ];
  };

  # @Baohaus (Nixos)
  flake.nixosModules."users/${username}@baohaus" = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules."feat/io/input-actions"
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
    home-manager.users.${username} = {config, ...}: {
      imports = [
        self.homeModules."feat/ai/pi"
        self.homeModules."feat/desktop/browser/helium"
        self.homeModules."feat/desktop/file-manager/thunar"
        self.homeModules."feat/desktop/manager/niri"
        self.homeModules."feat/desktop/shell/awww"
        self.homeModules."feat/desktop/shell/dms"
        self.homeModules."feat/dev/git"
        self.homeModules."feat/dev/nvim"
        self.homeModules."feat/gaming/discord"
        self.homeModules."feat/gaming/harbourmasters"
        self.homeModules."feat/gaming/retroarch"
        self.homeModules."feat/io/input-actions"
        self.homeModules."feat/io/kanshi"
        self.homeModules."feat/media/playback/ani-cli"
        self.homeModules."feat/media/playback/spotify"
        self.homeModules."feat/media/playback/streamlink"
        self.homeModules."feat/media/reader/zathura"
        self.homeModules."feat/media/services/torrra"
        self.homeModules."feat/sync/maestral"
        self.homeModules."feat/system/mime"
        self.homeModules."feat/system/systools"
        self.homeModules."feat/system/theme"
        self.homeModules."feat/terminal/emulator/foot"
        self.homeModules."feat/terminal/emulator/ghostty"
        self.homeModules."feat/terminal/shell/zsh"
      ];
      mod."feat/desktop/shell/awww".img =
        ../../../assets/wallpapers/girl_leaving_apartment.png;
      mod."feat/gaming/harbourmasters" =
        builtins.mapAttrs (_: paths: {
          enable = true;
          gamepaths = paths;
        }) {
          shipofharkinian = ["${config.home.homeDirectory}/Downloads/Emulation/Games/oot.v64"];
          ghostship = ["${config.home.homeDirectory}/Downloads/Emulation/Games/sm64.z64"];
        };
    };
  };

  # @Zeltennia (Nixos)
  flake.nixosModules."users/${username}@zeltennia" = {pkgs, ...}: {
    imports = [
      self.nixosModules."feat/terminal/shell/zsh"
    ];
    users.users.${username} = {
      isNormalUser = true;
      description = username;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      initialPassword = "gobears";
      shell = pkgs.zsh;
    };
    nix.settings.trusted-users = [username];
    home-manager.users.${username}.imports = [
      self.homeModules."feat/dev/git"
      self.homeModules."feat/terminal/shell/zsh"
    ];
  };
}
