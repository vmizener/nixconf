{
  flake.nixosModules."hardware/zeltennia" = {
    lib,
    modulesPath,
    ...
  }: {
    imports = [
      (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
    ];

    # Avoid pulling ZFS into the kernel/initrd
    boot.supportedFilesystems = lib.mkForce ["vfat" "ext4"];
    sdImage.compressImage = true;

    zramSwap = {
      enable = true;
      memoryPercent = 50;
    };

    networking.useDHCP = lib.mkDefault true;
    nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  };
}
