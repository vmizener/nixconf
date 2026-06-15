{ self, inputs, ... }: let
  username = "bao";
in {
  # @Igros (Nixos)
  flake.nixosModules."users/${username}@igros" = {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    users.users.${username} = {
      isNormalUser = true;
      description = "${username}";
      extraGroups = [ "networkmanager" "wheel" ];
      initialPassword = "gobears";
    };
  };
}
