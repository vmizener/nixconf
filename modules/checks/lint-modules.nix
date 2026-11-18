{
  config,
  inputs,
  lib,
  options,
  self,
  ...
}: {
  # Module & option contract checks evaluated by `nix flake check`
  perSystem = {pkgs, ...}: {
    checks."lint:modules" = let
      repoPrefix = "${toString ../.}/";
      commonPrefix = "${toString ../common}/";
      sitePrefix = "${toString ../common/site}/";
      featuresPrefix = "${toString ../features}/";
      commonOptionsFile = toString ../common/options.nix;
      siteMetaFile = toString ../common/site/default.nix;
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

      featNixos = lib.filterAttrs (k: _: lib.hasPrefix "feat/" k) self.nixosModules;
      featHm = lib.filterAttrs (k: _: lib.hasPrefix "feat/" k) self.homeModules;

      allNixosEval = inputs.nixpkgs.lib.nixosSystem {
        modules =
          [
            {
              system.stateVersion = "25.11";
              nixpkgs.hostPlatform = "x86_64-linux";
            }
            self.nixosModules."common"
          ]
          ++ builtins.attrValues featNixos;
      };
      allHmEval = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
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

      # 1. Enforce top-level flake option namespaces (`options.site.*` under `modules/common/site/`)
      allowedRepoFlakeTopOpts = ["flake" "perSystem" "site"];
      flakeTopOptionErrors =
        options
        |> lib.filterAttrs (k: _: !(lib.hasPrefix "_" k) && !(builtins.elem k allowedRepoFlakeTopOpts))
        |> lib.mapAttrsToList (
          k: v: let
            repoDecls =
              lib.unique (collectOptionDecls {${k} = v;})
              |> builtins.filter (lib.hasPrefix repoPrefix);
          in
            lib.optional (repoDecls != [])
            "Unexpected top-level flake option 'options.${k}' (declared in ${lib.concatStringsSep ", " repoDecls}); use options.site.* under modules/common/site/ for flake-wide data and common/options for NixOS/HM options.mod.*"
        )
        |> lib.concatLists;

      siteNamespaceErrors = let
        siteOpts = lib.filterAttrs (k: _: !(lib.hasPrefix "_" k)) (options.site or {});
        siteDeclFiles = lib.unique (collectOptionDecls siteOpts);
        nsErrors = lib.concatLists (
          lib.mapAttrsToList (
            ns: subOpts: let
              declFiles = lib.unique (collectOptionDecls {${ns} = subOpts;});
            in
              if ns == "meta"
              then
                declFiles
                |> builtins.filter (f: f != siteMetaFile)
                |> map (f: "${f}: declares options under options.site.meta (only modules/common/site/default.nix may declare options.site.meta.*)")
              else
                declFiles
                |> lib.concatMap (
                  file:
                    if expectedSiteFor file == null
                    then ["${file}: declares options under options.site.\"${ns}\" outside modules/common/site/"]
                    else let
                      inherit (expectedSiteFor file) label expectedSite;
                    in
                      lib.optional (expectedSite != ns)
                      "${label}: declares options under options.site.\"${ns}\" (expected options.site.\"${expectedSite}\")"
                )
          )
          siteOpts
        );
        siteFileErrors =
          lib.filesystem.listFilesRecursive ../common/site
          |> map toString
          |> builtins.filter (f: lib.hasSuffix ".nix" f && !(lib.hasPrefix "_" (baseNameOf f)))
          |> lib.concatMap (
            f: let
              inherit (expectedSiteFor f) label expectedSite;
            in
              lib.optional (lib.hasInfix "/" expectedSite)
              "${label}: nested site namespace '${expectedSite}' is disallowed; use modules/common/site/<name>.nix or <name>/default.nix"
              ++ lib.optional (!(builtins.elem f siteDeclFiles))
              "${label}: does not declare any options under options.site.${expectedSite}"
          );
        siteSchemaErrors =
          config.site.meta.assertions
          |> builtins.filter (a: !a.assertion)
          |> map (a: a.message);
      in
        nsErrors ++ siteFileErrors ++ siteSchemaErrors;

      # 2. Verify module export keys and non-empty `common/options` blocks per file
      fileExportErrors = let
        nixosOptFiles = collectOptionDecls self.nixdOptions.nixos.options.mod;
        hmOptFiles = collectOptionDecls self.nixdOptions.home.options.mod;
        managedDefs =
          options.flake.definitionsWithLocations
          |> builtins.filter (d: expectedModFor d.file != null)
          |> builtins.groupBy (d: d.file);
      in
        lib.concatLists (
          lib.mapAttrsToList (
            file: defs: let
              inherit (expectedModFor file) label expectedMod;
              nixosKeys = lib.unique (lib.concatMap (d: builtins.attrNames (d.value.nixosModules or {})) defs);
              hmKeys = lib.unique (lib.concatMap (d: builtins.attrNames (d.value.homeModules or {})) defs);
              allKeys = nixosKeys ++ hmKeys;
              allowedKeys = lib.unique [expectedMod "common/options"];
              exportsMod = expectedMod != "common/options" && builtins.elem expectedMod allKeys;
            in
              if file == siteMetaFile
              then [
                "${label}: owns options.site.meta.* and may not export flake.{nixosModules,homeModules} (exported: ${lib.concatStringsSep ", " (lib.unique allKeys)})"
              ]
              else
                (
                  lib.unique allKeys
                  |> builtins.filter (k: !(builtins.elem k allowedKeys))
                  |> map (k: "${label}: exports unexpected module '${k}' (expected '${expectedMod}')")
                )
                ++ lib.optional (exportsMod && builtins.elem "common/options" nixosKeys && !(builtins.elem expectedMod nixosKeys))
                "${label}: defines flake.nixosModules.\"common/options\" without flake.nixosModules.\"${expectedMod}\""
                ++ lib.optional (exportsMod && builtins.elem "common/options" hmKeys && !(builtins.elem expectedMod hmKeys))
                "${label}: defines flake.homeModules.\"common/options\" without flake.homeModules.\"${expectedMod}\""
                ++ lib.optional (builtins.elem "common/options" nixosKeys && !(builtins.elem file nixosOptFiles))
                "${label}: defines flake.nixosModules.\"common/options\" without declaring any options under options.mod"
                ++ lib.optional (builtins.elem "common/options" hmKeys && !(builtins.elem file hmOptFiles))
                "${label}: defines flake.homeModules.\"common/options\" without declaring any options under options.mod"
          )
          managedDefs
        );

      # 3. Verify `options.mod.*` keys match `meta`, `"common/<name>"`, or `"feat/<path>"`
      checkOptNamespaces = kind: modOptSet:
        lib.concatLists (
          lib.mapAttrsToList (
            ns: subOpts: let
              declFiles = lib.unique (collectOptionDecls {${ns} = subOpts;});
              checkDirPrefix = dirPrefix: dirName:
                declFiles
                |> lib.concatMap (
                  file:
                    if !(lib.hasPrefix dirPrefix file)
                    then ["${file}: declares ${kind} options under options.mod.\"${ns}\" outside modules/${dirName}/"]
                    else if file == siteMetaFile
                    then ["${file}: declares ${kind} options under options.mod.\"${ns}\" (modules/common/site/default.nix may only declare options.site.meta.*)"]
                    else let
                      inherit (expectedModFor file) label expectedMod;
                    in
                      lib.optional (expectedMod != ns)
                      "${label}: declares ${kind} options under options.mod.\"${ns}\" (expected options.mod.\"${expectedMod}\")"
                );
            in
              if ns == "meta"
              then
                declFiles
                |> builtins.filter (f: f != commonOptionsFile)
                |> map (f: "${f}: declares ${kind} options under options.mod.meta (only modules/common/options.nix may declare options.mod.meta.*)")
              else if lib.hasPrefix "common/" ns
              then checkDirPrefix commonPrefix "common"
              else if lib.hasPrefix "feat/" ns
              then checkDirPrefix featuresPrefix "features"
              else [
                "Unexpected ${kind} option namespace options.mod.\"${ns}\" (declared in ${lib.concatStringsSep ", " declFiles}); expected options.mod.meta, options.mod.\"common/<name>\", or options.mod.\"feat/<path>\""
              ]
          )
          modOptSet
        );

      # 4. Verify every exported `common`/`feat` module registers `mod.meta.imported`
      checkModImported = kind: modAttrs: importedDefs: let
        registeredNames = lib.concatMap (d: d.value) importedDefs;
        missingErrors =
          builtins.attrNames modAttrs
          |> builtins.filter (k: !(builtins.elem k registeredNames))
          |> map (k: "${kind}.${k}: missing `mod.meta.imported = [\"${k}\"]`");
        mismatchErrors =
          importedDefs
          |> map (d: {
            file = stripVia d.file;
            values = d.value;
          })
          |> builtins.filter (d: expectedModFor d.file != null)
          |> lib.concatMap (
            d: let
              inherit (expectedModFor d.file) label expectedMod;
            in
              d.values
              |> builtins.filter (v: v != expectedMod)
              |> map (v: "${label}: sets mod.meta.imported to '${v}' (expected '${expectedMod}')")
          );
      in
        missingErrors ++ mismatchErrors;

      trackedModFilter = k: _: k == "common" || lib.hasPrefix "common/" k || lib.hasPrefix "feat/" k;
      trackedNixos = lib.filterAttrs trackedModFilter self.nixosModules;
      trackedHm = lib.filterAttrs trackedModFilter self.homeModules;

      # 5. Verify `mod.meta.asserts` entries are internally consistent and have NixOS peers when required
      assertErrors =
        allHmEval.options.mod.meta.asserts.definitionsWithLocations
        |> builtins.filter (d: d.value != [] && expectedModFor (stripVia d.file) != null)
        |> lib.concatMap (d: let
          inherit (expectedModFor (stripVia d.file)) label expectedMod;
          vals = lib.unique d.value;
          featAsserts = builtins.filter (v: builtins.elem v ["pairedNixosFeat" "conflictsNixosFeat"]) vals;
        in
          (
            featAsserts
            |> builtins.filter (_: !(self.nixosModules ? ${expectedMod}))
            |> map (v: "${label}: sets mod.meta.asserts '${v}' without flake.nixosModules.\"${expectedMod}\"")
          )
          ++ lib.optional (builtins.elem "nixosOnly" vals && builtins.elem "standaloneOnly" vals)
          "${label}: sets contradictory mod.meta.asserts ('nixosOnly' and 'standaloneOnly')"
          ++ lib.optional (builtins.elem "pairedNixosFeat" vals && builtins.elem "conflictsNixosFeat" vals)
          "${label}: sets contradictory mod.meta.asserts ('pairedNixosFeat' and 'conflictsNixosFeat')"
          ++ (
            if builtins.elem "standaloneOnly" vals
            then map (v: "${label}: sets contradictory mod.meta.asserts ('standaloneOnly' with '${v}')") featAsserts
            else []
          ));

      # 6. Disallow cross-feature `mod."feat/*"` option definitions and references
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

      checkCrossFeatDefs = kind: modOptSet:
        modOptSet
        |> lib.filterAttrs (ns: _: lib.hasPrefix "feat/" ns)
        |> lib.mapAttrsToList (
          ns: subOpts:
            lib.unique (collectOptionDefs subOpts)
            |> builtins.filter (f: expectedModFor f != null)
            |> lib.concatMap (
              file: let
                inherit (expectedModFor file) label expectedMod;
              in
                lib.optional (expectedMod != ns)
                "${label}: defines ${kind} options under mod.\"${ns}\" (cross-feature mod option references are disallowed)"
            )
        )
        |> lib.concatLists;

      stripComments = text: let
        noBlocks =
          builtins.split "[/][*]([^*]|[*]+[^*/])*[*]+[/]" text
          |> builtins.filter builtins.isString
          |> lib.concatStringsSep " ";
      in
        lib.splitString "\n" noBlocks
        |> map (
          line:
            if builtins.match "[[:space:]]*#.*" line != null
            then ""
            else builtins.head (builtins.split "[[:space:]]+#.*" line)
        )
        |> lib.concatStringsSep "\n";

      extractFeatModRefs = text:
        builtins.split "mod([[:space:]]+or[[:space:]]+[{][[:space:]]*[}])?[)]*[[:space:]]*[.][[:space:]]*\"(feat/[^\"$]+)\"" (stripComments text)
        |> builtins.filter builtins.isList
        |> map lib.last
        |> lib.unique;

      managedNixFiles =
        (lib.filesystem.listFilesRecursive ../common ++ lib.filesystem.listFilesRecursive ../features)
        |> map toString
        |> builtins.filter (lib.hasSuffix ".nix");

      crossFeatRefErrors =
        managedNixFiles
        |> lib.concatMap (
          file: let
            inherit (expectedModFor file) label expectedMod;
          in
            extractFeatModRefs (builtins.readFile file)
            |> builtins.filter (ref: ref != expectedMod)
            |> map (ref: "${label}: references mod.\"${ref}\" (cross-feature mod option references are disallowed)")
        );

      errors = builtins.seq allHmEval.config.mod.meta.asserts (
        flakeTopOptionErrors
        ++ siteNamespaceErrors
        ++ fileExportErrors
        ++ checkOptNamespaces "NixOS" self.nixdOptions.nixos.options.mod
        ++ checkOptNamespaces "Home-Manager" self.nixdOptions.home.options.mod
        ++ checkModImported "nixosModules" trackedNixos allNixosEval.options.mod.meta.imported.definitionsWithLocations
        ++ checkModImported "homeModules" trackedHm allHmEval.options.mod.meta.imported.definitionsWithLocations
        ++ assertErrors
        ++ checkCrossFeatDefs "NixOS" allNixosEval.options.mod
        ++ checkCrossFeatDefs "Home-Manager" allHmEval.options.mod
        ++ crossFeatRefErrors
      );
    in
      if errors == []
      then pkgs.emptyFile
      else throw "Module drift detected:\n- ${lib.concatStringsSep "\n- " errors}";
  };
}
