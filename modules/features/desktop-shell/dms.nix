/*
  feat/desktop-shell/dms

Enables the Dank Material Shell Wayland desktop shell.

Exposes:

- flake.homeModules."feat/desktop-shell/dms":
*/
{inputs, ...}: {
  flake.homeModules."feat/desktop-shell/dms" = {pkgs, ...}: {
    imports = [
      inputs.dms.homeModules.dank-material-shell
      inputs.danksearch.homeModules.default
    ];
    home.packages = with pkgs; [
      cava
      khal
      matugen
      wtype
    ];
    programs.dank-material-shell = {
      enable = true;
      dgop.package = inputs.dgop.packages.${pkgs.stdenv.hostPlatform.system}.default;
      systemd = {
        enable = true;
        restartIfChanged = true;
      };
      enableSystemMonitoring = true;
      enableVPN = true;
      enableDynamicTheming = true;
      enableAudioWavelength = true;
      enableCalendarEvents = true;
      enableClipboardPaste = true;
      settings = {
        currentThemeName = "blue";
        currentThemeCategory = "generic";
        screenPreferences.wallpaper = [];
      };
    };
    programs.dsearch.enable = true;
  };
}
