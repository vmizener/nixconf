# Shared QEMU display/machine argument builders and helpers for `feat/vm`.
{lib}: {
  boolToStr = b:
    if b
    then "1"
    else "0";

  mkDisplayArgs = {
    cfg,
    serialStdio ? false,
  }: let
    vgaDevice =
      if cfg.gl
      then "virtio-vga-gl"
      else "virtio-vga";
    resOpts =
      lib.optionalString (cfg.resolution != null)
      ",edid=on,xres=${toString cfg.resolution.width},yres=${toString cfg.resolution.height}";
    sdlOpts =
      if cfg.gl
      then "sdl,gl=on"
      else "sdl";
  in
    lib.optionals cfg.graphics (
      [
        "-vga"
        "none"
        "-device"
        "${vgaDevice}${resOpts}"
        "-display"
        sdlOpts
      ]
      ++ lib.optionals serialStdio [
        "-serial"
        "mon:stdio"
      ]
    );

  mkHmStaticArgs = {
    cfg,
    pkgs,
    runtimeDir,
    seedIso,
    system,
  }: let
    machineArgs =
      if system == "aarch64-linux"
      then ["-machine" "virt" "-bios" "${pkgs.OVMF.fd}/FV/QEMU_EFI.fd"]
      else ["-machine" "q35"];
  in
    machineArgs
    ++ [
      "-m"
      (toString cfg.memorySize)
      "-smp"
      (toString cfg.cores)
      "-netdev"
      "user,id=net0"
      "-device"
      "virtio-net-pci,netdev=net0"
      "-device"
      "virtio-rng-pci"
      "-usb"
      "-device"
      "usb-tablet"
      "-drive"
      "file=${seedIso},format=raw,if=virtio,readonly=on"
      "-virtfs"
      "local,path=/nix/store,security_model=none,mount_tag=host-nix-store,readonly=on"
      "-virtfs"
      "local,path=${runtimeDir},security_model=none,mount_tag=hm-vm,readonly=on"
    ];
}
