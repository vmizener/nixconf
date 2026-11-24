/*
  common (assertions)

Runtime `mod.meta.*`, `site.meta.assertions`, Home-Manager/NixOS boundary
(`mod.meta.asserts`), and unimported-feature option assertions evaluated on
NixOS and Home-Manager builds.
*/
{
  lib,
  self,
  ...
} @ flake: let
  siteAssertions = flake.config.site.meta.assertions;

  importedAssertions = modAttr: validModules: config:
    map (name: {
      assertion = validModules ? ${name};
      message = "mod.meta.imported contains '${name}', which is not an exported flake.${modAttr} module.";
    })
    config.mod.meta.imported;

  metaPathAssertions = {
    flakePath,
    nixconfPath,
  }:
    [
      {
        assertion = lib.hasPrefix "/" flakePath;
        message = "mod.meta.flakePath ('${flakePath}') must be an absolute path.";
      }
    ]
    ++ lib.optional (nixconfPath != null) {
      assertion = lib.hasPrefix "/" nixconfPath;
      message = "mod.meta.nixconfPath ('${nixconfPath}') must be an absolute path.";
    };

  collectExplicitPaths = viaCommonOptions: prefix: optSet:
    lib.concatLists (
      lib.mapAttrsToList (
        k: v: let
          path = prefix ++ [k];
          explicitDefs =
            if lib.isOption v
            then builtins.filter (d: !(lib.hasSuffix viaCommonOptions d.file)) v.definitionsWithLocations
            else [];
        in
          if lib.isOption v
          then lib.optional (explicitDefs != []) (lib.showOption path)
          else if builtins.isAttrs v
          then collectExplicitPaths viaCommonOptions path v
          else []
      )
      optSet
    );

  unimportedFeatAssertions = modAttr: config: modOptSet: let
    viaCommonOptions = ", via option ${lib.showOption ["flake" modAttr "common/options"]}";
  in
    modOptSet
    |> lib.filterAttrs (ns: _: lib.hasPrefix "feat/" ns && !(config.mod.meta.has ns))
    |> lib.mapAttrsToList (
      ns: subOpts: let
        definedPaths = collectExplicitPaths viaCommonOptions ["mod" ns] subOpts;
      in
        lib.optional (definedPaths != []) {
          assertion = false;
          message = "mod.\"${ns}\" options are defined (${lib.concatStringsSep ", " definedPaths}), but flake.${modAttr}.\"${ns}\" is not imported.";
        }
    )
    |> lib.concatLists;
in {
  flake.nixosModules."common" = {
    config,
    options,
    ...
  }: {
    config.assertions =
      siteAssertions
      ++ importedAssertions "nixosModules" self.nixosModules config
      ++ metaPathAssertions {
        inherit (config.mod.meta) flakePath nixconfPath;
      }
      ++ unimportedFeatAssertions "nixosModules" config options.mod;
  };

  flake.homeModules."common" = {
    config,
    options,
    osConfig ? null,
    ...
  }: let
    hmLocMap =
      lib.mapAttrs' (
        name: _:
          lib.nameValuePair (lib.showOption ["flake" "homeModules" name]) name
      )
      self.homeModules;
    hostSuffix =
      if osConfig != null
      then " on NixOS host '${osConfig.networking.hostName}'"
      else "";
    contradictoryAsserts = name: vals: let
      featAsserts = builtins.filter (v: builtins.elem v ["pairedNixosFeat" "conflictsNixosFeat"]) vals;
      label =
        if name != null
        then "flake.homeModules.\"${name}\""
        else "mod.meta.asserts";
    in
      lib.optional (builtins.elem "nixosOnly" vals && builtins.elem "standaloneOnly" vals) {
        assertion = false;
        message = "${label}: contradictory mod.meta.asserts ('nixosOnly' and 'standaloneOnly').";
      }
      ++ lib.optional (builtins.elem "pairedNixosFeat" vals && builtins.elem "conflictsNixosFeat" vals) {
        assertion = false;
        message = "${label}: contradictory mod.meta.asserts ('pairedNixosFeat' and 'conflictsNixosFeat').";
      }
      ++ (
        if builtins.elem "standaloneOnly" vals
        then
          map (v: {
            assertion = false;
            message = "${label}: contradictory mod.meta.asserts ('standaloneOnly' with '${v}').";
          })
          featAsserts
        else []
      );
    mkModuleAssert = {
      file,
      name,
      kind,
    }:
      if name == null
      then {
        assertion = false;
        message = "mod.meta.asserts ('${kind}') must be set inside an exported flake.homeModules.<name> module (found in '${file}').";
      }
      else if kind == "nixosOnly"
      then {
        assertion = osConfig != null;
        message = "flake.homeModules.\"${name}\" is only supported on NixOS hosts (unsupported in standalone Home-Manager).";
      }
      else if kind == "standaloneOnly"
      then {
        assertion = osConfig == null;
        message = "flake.homeModules.\"${name}\" is only supported in standalone Home-Manager configurations${hostSuffix}.";
      }
      else if !(self.nixosModules ? ${name})
      then {
        assertion = false;
        message = "flake.homeModules.\"${name}\" sets mod.meta.asserts '${kind}', but flake.nixosModules.\"${name}\" does not exist.";
      }
      else if kind == "pairedNixosFeat"
      then {
        assertion = osConfig == null || osConfig.mod.meta.has name;
        message = "flake.homeModules.\"${name}\" expects paired flake.nixosModules.\"${name}\" to be imported${hostSuffix}.";
      }
      else if kind == "conflictsNixosFeat"
      then {
        assertion = osConfig == null || !(osConfig.mod.meta.has name);
        message = "flake.homeModules.\"${name}\" conflicts with flake.nixosModules.\"${name}\" and cannot both be imported${hostSuffix}.";
      }
      else throw "Unhandled mod.meta.asserts kind '${kind}'";
    moduleAssertDefs =
      options.mod.meta.asserts.definitionsWithLocations
      |> lib.concatMap (d: let
        parts = lib.splitString ", via option " d.file;
        viaOpt = lib.last parts;
        name =
          if builtins.length parts > 1 && hmLocMap ? ${viaOpt}
          then hmLocMap.${viaOpt}
          else null;
        vals = lib.unique d.value;
      in
        contradictoryAsserts name vals
        ++ map (kind:
          mkModuleAssert {
            inherit (d) file;
            inherit name kind;
          })
        vals);
  in {
    config.assertions =
      lib.optionals (osConfig == null) siteAssertions
      ++ importedAssertions "homeModules" self.homeModules config
      ++ metaPathAssertions {
        inherit (config.mod.meta) flakePath nixconfPath;
      }
      ++ unimportedFeatAssertions "homeModules" config options.mod
      ++ builtins.seq config.mod.meta.asserts moduleAssertDefs;
  };
}
