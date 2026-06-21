lib: pkgs: let
  # isVm = config.virtualisation.qemu.guest.enable;
in {
  environment = {
    DISPLAY = ":0";
    QT_QPA_PLATFORM = "wayland";
    NIRI_NO_HARDWARE_CURSORS = "1";
    WAYLAND_DISPLAY = "wayland-1";
  };
  input.keyboard = {
    xkb.layout = "us";
    # mod-key = lib.mkIf isVm "Alt";
    # mod-key-nested = lib.mkIf isVm "Mod5";
  };
  spawn-at-startup = [
    "${lib.getExe pkgs.foot}"
  ];
}
