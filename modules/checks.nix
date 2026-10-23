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
          isDefaultNix = lib.hasSuffix "/default.nix" relPath;
          nixosKeys = lib.unique (lib.concatMap (d: builtins.attrNames (d.value.nixosModules or {})) defs);
          hmKeys = lib.unique (lib.concatMap (d: builtins.attrNames (d.value.homeModules or {})) defs);
          allKeys = nixosKeys ++ hmKeys;
          allowedKeys = [expectedFeat "common/options"] ++ lib.optional isDefaultNix "common";
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

    errors =
      fileExportErrors
      ++ checkOptNamespaces "NixOS" self.nixdOptions.nixos.options.mod
      ++ checkOptNamespaces "Home-Manager" self.nixdOptions.home.options.mod
      ++ checkModImported "nixosModules" featNixos allNixosEval.options.mod.imported.definitionsWithLocations
      ++ checkModImported "homeModules" featHm allHmEval.options.mod.imported.definitionsWithLocations;
  in
    if errors == []
    then true
    else throw "Feature module drift detected:\n- ${lib.concatStringsSep "\n- " errors}";
in {
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
