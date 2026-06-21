config: lib: pkgs: {
  environment = {
    DISPLAY = ":0";
    QT_QPA_PLATFORM = "wayland";
    NIRI_NO_HARDWARE_CURSORS = "1";
    WAYLAND_DISPLAY = "wayland-1";
  };
  input.keyboard = {
    xkb.layout = "us";
    mod-key = lib.mkIf config.features.vm.isVm "Alt";
    mod-key-nested = lib.mkIf config.features.vm.isVm "Mod5";
  };
  spawn-at-startup = [
    "${lib.getExe pkgs.foot}"
  ];
}
