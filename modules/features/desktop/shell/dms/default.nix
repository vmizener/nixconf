/*
 feat/desktop/shell/dms

Enables the Dank Material Shell Wayland desktop shell.

Exposes:

- flake.homeModules."feat/desktop/shell/dms":
*/
{inputs, ...}: let
  moduleName = "feat/desktop/shell/dms";
in {
  flake.homeModules.${moduleName} = {pkgs, ...}: {
    mod.meta.imported = [moduleName];
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
      settings = builtins.fromJSON (builtins.readFile ./_settings.json);
    };
    programs.dsearch.enable = true;
    mod."common/handlers".add = {
      launcher.dms = {
        priority = 100;
        label = "DMS Spotlight";
        cmd = ["dms" "ipc" "spotlight" "open"];
      };
      clipboard.dms = {
        priority = 100;
        label = "DMS";
        cmd = ["dms" "ipc" "call" "clipboard" "toggle"];
      };
      notifier.dms = {
        priority = 100;
        label = "DMS";
        actions = {
          dismiss.cmd = ["dms" "ipc" "call" "notifications" "dismissAllPopups"];
          restore.cmd = ["dms" "ipc" "call" "notifications" "toggle"];
        };
      };
      powerMenu.dms = {
        priority = 100;
        label = "DMS";
        cmd = ["dms" "ipc" "powermenu" "toggle"];
      };
    };
  };
}
