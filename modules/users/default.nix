{
  config,
  lib,
  self,
  ...
}: {
  # Readonly helper to construct a Home-Manager user@host module
  options.mod.mkHomeUser = lib.mkOption {
    readOnly = true;
    description = "Construct a Home-Manager user@host module";
    default = {
      username,
      shell ? "zsh",
      hmImports ? [],
      hmConfig ? {},
    }: {osConfig ? null, ...}: {
      imports =
        [self.homeModules."common"]
        ++ lib.optional (shell != null) self.homeModules."feat/terminal/shell/${shell}"
        ++ hmImports
        ++ [hmConfig];

      home = lib.optionalAttrs (osConfig == null) {
        inherit username;
        homeDirectory = lib.mkOptionDefault "/home/${username}";
      };
    };
  };

  # Readonly helper to construct a NixOS + Home-Manager user@host module
  options.mod.mkNixosUser = lib.mkOption {
    readOnly = true;
    description = "Construct a NixOS + Home-Manager user@host module";
    default = {
      username,
      shell ? "zsh",
      extraGroups ? [],
      userConfig ? {},
      nixosImports ? [],
      nixosConfig ? {},
      hmImports ? [],
      hmConfig ? {},
    }: {pkgs, ...}: {
      imports =
        lib.optional (shell != null) self.nixosModules."feat/terminal/shell/${shell}"
        ++ nixosImports
        ++ [nixosConfig];

      users.users.${username} =
        {
          isNormalUser = true;
          description = username;
          extraGroups = lib.unique (["networkmanager" "wheel"] ++ extraGroups);
        }
        // lib.optionalAttrs (shell != null) {
          shell =
            if shell == "bash"
            then pkgs.bashInteractive
            else pkgs.${shell};
        }
        // userConfig;

      home-manager.users.${username} = config.mod.mkHomeUser {
        inherit username shell hmImports hmConfig;
      };
    };
  };
}
