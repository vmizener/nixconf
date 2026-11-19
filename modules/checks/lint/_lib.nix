# Shared path constants, option-tree walkers, and source inspection helpers for `lint:modules`.
{lib}: let
  modulesDir = ../..;
  commonDir = modulesDir + "/common";
  siteDir = commonDir + "/site";
  featuresDir = modulesDir + "/features";

  commonPrefix = "${toString commonDir}/";
  sitePrefix = "${toString siteDir}/";
  featuresPrefix = "${toString featuresDir}/";

  stripVia = s: builtins.head (lib.splitString ", via option " s);

  modSuffixFor = relPath:
    if lib.hasPrefix "_" (baseNameOf relPath)
    then let
      dir = dirOf relPath;
    in
      if dir == "."
      then ""
      else dir
    else if lib.hasSuffix "/default.nix" relPath
    then lib.removeSuffix "/default.nix" relPath
    else lib.removeSuffix ".nix" relPath;

  collectOptionDecls = optSet:
    lib.concatLists (
      lib.mapAttrsToList (
        _: v:
          if lib.isOption v
          then map stripVia v.declarations
          else if builtins.isAttrs v
          then collectOptionDecls v
          else []
      )
      optSet
    );

  collectOptionDefs = optSet:
    lib.concatLists (
      lib.mapAttrsToList (
        _: v:
          if lib.isOption v
          then map (d: stripVia d.file) v.definitionsWithLocations
          else if builtins.isAttrs v
          then collectOptionDefs v
          else []
      )
      optSet
    );
in {
  inherit
    collectOptionDecls
    collectOptionDefs
    commonDir
    commonPrefix
    featuresDir
    featuresPrefix
    siteDir
    stripVia
    ;

  repoPrefix = "${toString modulesDir}/";
  commonOptionsFile = toString (commonDir + "/options.nix");
  siteMetaFile = toString (siteDir + "/default.nix");

  expectedSiteFor = file:
    if !(lib.hasPrefix sitePrefix file)
    then null
    else let
      relPath = lib.removePrefix sitePrefix file;
      modSuffix = modSuffixFor relPath;
    in {
      label = "common/site/${relPath}";
      expectedSite =
        if relPath == "default.nix" || modSuffix == ""
        then "meta"
        else modSuffix;
    };

  expectedModFor = file:
    if lib.hasPrefix commonPrefix file
    then let
      relPath = lib.removePrefix commonPrefix file;
      modSuffix = modSuffixFor relPath;
    in {
      label = "common/${relPath}";
      expectedMod =
        if builtins.elem relPath ["default.nix" "assertions.nix"] || modSuffix == ""
        then "common"
        else "common/${modSuffix}";
    }
    else if lib.hasPrefix featuresPrefix file
    then let
      relPath = lib.removePrefix featuresPrefix file;
      modSuffix = modSuffixFor relPath;
    in {
      label = "features/${relPath}";
      expectedMod =
        if modSuffix == ""
        then "feat"
        else "feat/${modSuffix}";
    }
    else null;

  extractFeatModRefs = text: let
    noBlocks =
      builtins.split "[/][*]([^*]|[*]+[^*/])*[*]+[/]" text
      |> builtins.filter builtins.isString
      |> lib.concatStringsSep " ";
    stripped =
      lib.splitString "\n" noBlocks
      |> map (
        line:
          if builtins.match "[[:space:]]*#.*" line != null
          then ""
          else builtins.head (builtins.split "[[:space:]]+#.*" line)
      )
      |> lib.concatStringsSep "\n";
  in
    builtins.split "mod([[:space:]]+or[[:space:]]+[{][[:space:]]*[}])?[)]*[[:space:]]*[.][[:space:]]*\"(feat/[^\"$]+)\"" stripped
    |> builtins.filter builtins.isList
    |> map lib.last
    |> lib.unique;
}
