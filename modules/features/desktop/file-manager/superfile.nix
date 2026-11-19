/*
  feat/desktop/file-manager/superfile

Superfile terminal file manager.

Exposes:

- flake.homeModules."feat/desktop/file-manager/superfile":
  - Enables Superfile with metadata panel support, installs a desktop entry on
    Linux, and registers it in `common/handlers`.
*/
{...}: let
  moduleName = "feat/desktop/file-manager/superfile";
in {
  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.mod."common/handlers".get) terminal;
  in {
    mod = {
      meta.imported = [moduleName];
      "common/handlers".add.fileManager.superfile = {
        priority = 175;
        label = "Superfile";
        desktop = "superfile.desktop";
        cmd =
          if terminal != null
          then ["xdg-terminal-exec" "--" "superfile"]
          else ["superfile"];
      };
    };
    programs.superfile = {
      enable = true;
      firstUseCheck = false;
      settings.metadata = true;
    };
    xdg.desktopEntries = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      superfile = {
        name = "Superfile";
        genericName = "File Manager";
        comment = "Terminal file manager";
        icon = "system-file-manager";
        exec = "superfile %F";
        terminal = true;
        categories = [
          "System"
          "FileTools"
          "FileManager"
          "ConsoleOnly"
        ];
        mimeType = ["inode/directory"];
      };
    };
  };
}
