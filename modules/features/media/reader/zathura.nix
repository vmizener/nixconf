/*
  feat/media/reader/zathura

Enables the open source Zathura document viewer.

Exposes:

- flake.homeModules."feat/media/reader/zathura":
*/
{...}: let
  moduleName = "feat/media/reader/zathura";
in {
  flake.homeModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
    programs.zathura.enable = true;

    mod."feat/system/mime".add.pdfViewer."org.pwmt.zathura.desktop" = 100;
  };
}
