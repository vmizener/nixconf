{
  inputs,
  lib,
  options,
  self,
  ...
}: let
  ################
  # Feature drift assertions (evaluated by `nix flake check`)
  featureDriftCheck = let
    featuresPrefix = "${toString ./features}/";
    stripVia = s: builtins.head (lib.splitString ", via option " s);
    featNameFor = relPath:
      "feat/"
      + (
        if lib.hasSuffix "/default.nix" relPath
        then lib.removeSuffix "/default.nix" relPath
        else lib.removeSuffix ".nix" relPath
      );

    featureDefs =
      options.flake.definitionsWithLocations
      |> builtins.filter (d: lib.hasPrefix featuresPrefix d.file)
      |> builtins.groupBy (d: d.file);

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

    nixosOptFiles = collectOptionDecls self.nixdOptions.nixos.options.mod;
    hmOptFiles = collectOptionDecls self.nixdOptions.home.options.mod;

    checkOptNamespaces = kind: modOptSet:
      lib.concatLists (
        lib.mapAttrsToList (
          ns: subOpts:
            if !(lib.hasPrefix "feat/" ns)
            then []
            else
              collectOptionDecls {${ns} = subOpts;}
              |> builtins.filter (f: lib.hasPrefix featuresPrefix f)
              |> lib.unique
              |> lib.concatMap (
                file: let
                  relPath = lib.removePrefix featuresPrefix file;
                  expectedFeat = featNameFor relPath;
                in
                  lib.optional (expectedFeat != ns)
                  "${relPath}: declares ${kind} options under options.mod.\"${ns}\" (expected options.mod.\"${expectedFeat}\")"
              )
        )
        modOptSet
      );

    featNixos = lib.filterAttrs (k: _: lib.hasPrefix "feat/" k) self.nixosModules;
    featHm = lib.filterAttrs (k: _: lib.hasPrefix "feat/" k) self.homeModules;

    allNixosEval = self.nixdOptions.nixos.extendModules {
      modules = builtins.attrValues featNixos;
    };
    allHmEval = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
      extraSpecialArgs = {osConfig = null;};
      modules =
        [
          {
            home.username = "options";
            home.homeDirectory = "/home/options";
            assertions = lib.mkForce [];
            warnings = lib.mkForce [];
          }
          self.homeModules."common"
        ]
        ++ builtins.attrValues featHm;
    };

    checkModImported = kind: featAttrs: importedDefs: let
      registeredNames = lib.concatMap (d: d.value) importedDefs;
      missingErrors =
        builtins.attrNames featAttrs
        |> builtins.filter (k: !(builtins.elem k registeredNames))
        |> map (k: "${kind}.${k}: missing `mod.imported = [\"${k}\"]`");
      mismatchErrors =
        importedDefs
        |> map (d: {
          file = stripVia d.file;
          values = d.value;
        })
        |> builtins.filter (d: lib.hasPrefix featuresPrefix d.file)
        |> lib.concatMap (
          d: let
            relPath = lib.removePrefix featuresPrefix d.file;
            expectedFeat = featNameFor relPath;
          in
            d.values
            |> builtins.filter (v: v != expectedFeat)
            |> map (v: "${relPath}: sets mod.imported to '${v}' (expected '${expectedFeat}')")
        );
    in
      missingErrors ++ mismatchErrors;

    fileExportErrors = lib.concatLists (
      lib.mapAttrsToList (
        file: defs: let
          relPath = lib.removePrefix featuresPrefix file;
          expectedFeat = featNameFor relPath;
          nixosKeys = lib.unique (lib.concatMap (d: builtins.attrNames (d.value.nixosModules or {})) defs);
          hmKeys = lib.unique (lib.concatMap (d: builtins.attrNames (d.value.homeModules or {})) defs);
          allKeys = nixosKeys ++ hmKeys;
          allowedKeys = [expectedFeat "common/options"];
          exportsFeat = builtins.elem expectedFeat allKeys;

          badKeyErrors =
            lib.unique allKeys
            |> builtins.filter (k: !(builtins.elem k allowedKeys))
            |> map (k: "${relPath}: exports unexpected module '${k}' (expected '${expectedFeat}')");

          orphanNixosOpts =
            lib.optional (exportsFeat && builtins.elem "common/options" nixosKeys && !(builtins.elem expectedFeat nixosKeys))
            "${relPath}: defines flake.nixosModules.\"common/options\" without flake.nixosModules.\"${expectedFeat}\"";

          orphanHmOpts =
            lib.optional (exportsFeat && builtins.elem "common/options" hmKeys && !(builtins.elem expectedFeat hmKeys))
            "${relPath}: defines flake.homeModules.\"common/options\" without flake.homeModules.\"${expectedFeat}\"";

          emptyNixosOpts =
            lib.optional (builtins.elem "common/options" nixosKeys && !(builtins.elem file nixosOptFiles))
            "${relPath}: defines flake.nixosModules.\"common/options\" without declaring any options under options.mod";

          emptyHmOpts =
            lib.optional (builtins.elem "common/options" hmKeys && !(builtins.elem file hmOptFiles))
            "${relPath}: defines flake.homeModules.\"common/options\" without declaring any options under options.mod";
        in
          badKeyErrors ++ orphanNixosOpts ++ orphanHmOpts ++ emptyNixosOpts ++ emptyHmOpts
      )
      featureDefs
    );

    checkModAsserts = defs:
      defs
      |> builtins.filter (d: d.value != [] && lib.hasPrefix featuresPrefix (stripVia d.file))
      |> lib.concatMap (d: let
        relPath = lib.removePrefix featuresPrefix (stripVia d.file);
        expectedFeat = featNameFor relPath;
        vals = lib.unique d.value;
        featAsserts = builtins.filter (v: builtins.elem v ["pairedNixosFeat" "conflictsNixosFeat"]) vals;
        missingNixosErrors =
          featAsserts
          |> builtins.filter (_: !(self.nixosModules ? ${expectedFeat}))
          |> map (v: "${relPath}: sets mod.asserts '${v}' without flake.nixosModules.\"${expectedFeat}\"");
        contradictionErrors =
          lib.optional (builtins.elem "nixosOnly" vals && builtins.elem "standaloneOnly" vals)
          "${relPath}: sets contradictory mod.asserts ('nixosOnly' and 'standaloneOnly')"
          ++ lib.optional (builtins.elem "pairedNixosFeat" vals && builtins.elem "conflictsNixosFeat" vals)
          "${relPath}: sets contradictory mod.asserts ('pairedNixosFeat' and 'conflictsNixosFeat')"
          ++ (
            if builtins.elem "standaloneOnly" vals
            then map (v: "${relPath}: sets contradictory mod.asserts ('standaloneOnly' with '${v}')") featAsserts
            else []
          );
      in
        missingNixosErrors ++ contradictionErrors);

    errors = builtins.seq allHmEval.config.mod.asserts (
      fileExportErrors
      ++ checkOptNamespaces "NixOS" self.nixdOptions.nixos.options.mod
      ++ checkOptNamespaces "Home-Manager" self.nixdOptions.home.options.mod
      ++ checkModImported "nixosModules" featNixos allNixosEval.options.mod.imported.definitionsWithLocations
      ++ checkModImported "homeModules" featHm allHmEval.options.mod.imported.definitionsWithLocations
      ++ checkModAsserts allHmEval.options.mod.asserts.definitionsWithLocations
    );
  in
    if errors == []
    then true
    else throw "Feature module drift detected:\n- ${lib.concatStringsSep "\n- " errors}";
  importedAssertions = validModules: config:
    map (name: {
      assertion = validModules ? ${name};
      message = "mod.imported contains '${name}', which is not an exported module.";
    })
    config.mod.imported;
in {
  ################
  # Module-level assertions (evaluated on NixOS & Home-Manager builds)
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
        message = "mod.asserts ('${kind}') must be set inside an exported flake.homeModules.<name> module (found in '${file}').";
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
        message = "flake.homeModules.\"${name}\" sets mod.asserts '${kind}', but flake.nixosModules.\"${name}\" does not exist.";
      }
      else if kind == "pairedNixosFeat"
      then {
        assertion = osConfig == null || osConfig.mod.has name;
        message = "flake.homeModules.\"${name}\" expects paired flake.nixosModules.\"${name}\" to be imported${hostSuffix}.";
      }
      else if kind == "conflictsNixosFeat"
      then {
        assertion = osConfig == null || !(osConfig.mod.has name);
        message = "flake.homeModules.\"${name}\" conflicts with flake.nixosModules.\"${name}\" and cannot both be imported${hostSuffix}.";
      }
      else throw "Unhandled mod.asserts kind '${kind}'";
    moduleAssertDefs =
      options.mod.asserts.definitionsWithLocations
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
      ++ builtins.seq config.mod.asserts moduleAssertDefs;
  };

  ################
  # Expose feature drift & standalone homeConfiguration checks to `nix flake check`
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks =
      {
        "lint:features" = builtins.seq featureDriftCheck pkgs.emptyFile;
      }
      // (
        self.homeConfigurations
        |> lib.filterAttrs (
          _: hmConf:
            hmConf.pkgs.stdenv.hostPlatform.system == system
        )
        |> lib.mapAttrs' (
          name: hmConf:
            lib.nameValuePair "hm:${name}" hmConf.activationPackage
        )
      );
  };
}
