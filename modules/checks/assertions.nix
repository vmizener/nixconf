{
  lib,
  self,
  ...
}: let
  importedAssertions = validModules: config:
    map (name: {
      assertion = validModules ? ${name};
      message = "mod.meta.imported contains '${name}', which is not an exported module.";
    })
    config.mod.meta.imported;
in {
  # Runtime `mod.meta.{imported,asserts}` assertions evaluated on NixOS & Home-Manager builds
  flake.nixosModules."common/options" = {config, ...}: {
    config.assertions = importedAssertions self.nixosModules config;
  };

  flake.homeModules."common/options" = {
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
      in
        map (kind:
          mkModuleAssert {
            inherit (d) file;
            inherit name kind;
          }) (lib.unique d.value));
  in {
    config.assertions =
      importedAssertions self.homeModules config
      ++ builtins.seq config.mod.meta.asserts moduleAssertDefs;
  };
}
