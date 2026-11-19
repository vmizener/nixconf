/*
  feat/desktop/file-manager/yazi

Yazi terminal file manager.

Exposes:

- flake.homeModules."feat/desktop/file-manager/yazi":
  - Enables Yazi with `y` cwd-on-exit shell integration for Bash and Zsh and
    registers it in `common/handlers`.
*/
{...}: let
  moduleName = "feat/desktop/file-manager/yazi";
in {
  flake.homeModules.${moduleName} = {config, ...}: let
    inherit (config.mod."common/handlers".get) terminal;
  in {
    mod = {
      meta.imported = [moduleName];
      "common/handlers".add.fileManager.yazi = {
        priority = 175;
        label = "Yazi";
        desktop = "yazi.desktop";
        cmd =
          if terminal != null
          then ["xdg-terminal-exec" "--" "yazi"]
          else ["yazi"];
      };
    };
    programs.yazi = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      shellWrapperName = "y";
    };
  };
}
