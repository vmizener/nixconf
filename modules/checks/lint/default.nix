{
  inputs,
  lib,
  self,
  ...
} @ flake: {
  # Module & option contract checks evaluated by `nix flake check`
  perSystem = {
    options,
    pkgs,
    system,
    ...
  }: {
    checks."lint:modules" = let
      lintLib = import ./_lib.nix {inherit lib;};
      inherit
        (lintLib)
        collectOptionDecls
        collectOptionDefs
        commonDir
        commonOptionsFile
        commonPrefix
        expectedModFor
        expectedSiteFor
        extractFeatModRefs
        featuresDir
        featuresPrefix
        repoPrefix
        siteDir
        siteMetaFile
        stripVia
        ;

      nixdOpts = self.nixdOptions.${system};
      featNixos = lib.filterAttrs (k: _: lib.hasPrefix "feat/" k) self.nixosModules;
      featHm = lib.filterAttrs (k: _: lib.hasPrefix "feat/" k) self.homeModules;

      allNixosEval = inputs.nixpkgs.lib.nixosSystem {
        modules =
          [
            {
              system.stateVersion = "25.11";
              nixpkgs.hostPlatform = system;
            }
            self.nixosModules."common"
          ]
          ++ builtins.attrValues featNixos;
      };

      allHmEval = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
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

      errors = builtins.seq allHmEval.config.mod.meta.asserts (lib.concatLists [
        # 1. Enforce top-level flake option namespaces (`options.site.*` under `modules/common/site/`)
        (let
          allowedRepoFlakeTopOpts = ["flake" "perSystem" "site"];
          siteOpts = lib.filterAttrs (k: _: !(lib.hasPrefix "_" k)) (flake.options.site or {});
          siteDeclFiles = lib.unique (collectOptionDecls siteOpts);

          flakeTopOptionErrors =
            flake.options
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
            lib.filesystem.listFilesRecursive siteDir
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
            flake.config.site.meta.assertions
            |> builtins.filter (a: !a.assertion)
            |> map (a: a.message);
        in
          flakeTopOptionErrors ++ nsErrors ++ siteFileErrors ++ siteSchemaErrors)

        # 2. Verify module export keys, `perSystem.packages` prefixes, and non-empty `common/options` blocks
        (let
          nixosOptFiles = collectOptionDecls nixdOpts.nixos.options.mod;
          hmOptFiles = collectOptionDecls nixdOpts.home.options.mod;
          managedDefs =
            flake.options.flake.definitionsWithLocations
            |> builtins.filter (d: expectedModFor d.file != null)
            |> builtins.groupBy (d: d.file);

          fileExportErrors = lib.concatLists (
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

          packageExportErrors =
            options.packages.definitionsWithLocations
            |> lib.concatMap (
              d: let
                file = stripVia d.file;
                modInfo = expectedModFor file;
                loc =
                  if modInfo != null
                  then modInfo.label
                  else file;
                keys = builtins.attrNames d.value;
              in
                if file == siteMetaFile && keys != []
                then [
                  "${loc}: owns options.site.meta.* and may not export perSystem.packages (exported: ${lib.concatStringsSep ", " keys})"
                ]
                else
                  keys
                  |> builtins.filter (k: builtins.match "pkg:.+" k == null)
                  |> map (k: "${loc}: exports unprefixed package '${k}' in perSystem.packages (expected 'pkg:<name>')")
            );
        in
          fileExportErrors ++ packageExportErrors)

        # 3. Verify `options.mod.*` keys match `meta`, `"common/<name>"`, or `"feat/<path>"`
        (let
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
        in
          checkOptNamespaces "NixOS" nixdOpts.nixos.options.mod
          ++ checkOptNamespaces "Home-Manager" nixdOpts.home.options.mod)

        # 4. Verify every exported `common`/`feat` module registers `mod.meta.imported`
        (let
          trackedModFilter = k: _: k == "common" || lib.hasPrefix "common/" k || lib.hasPrefix "feat/" k;
          trackedNixos = lib.filterAttrs trackedModFilter self.nixosModules;
          trackedHm = lib.filterAttrs trackedModFilter self.homeModules;

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
        in
          checkModImported "nixosModules" trackedNixos allNixosEval.options.mod.meta.imported.definitionsWithLocations
          ++ checkModImported "homeModules" trackedHm allHmEval.options.mod.meta.imported.definitionsWithLocations)

        # 5. Verify `mod.meta.asserts` entries are internally consistent and have NixOS peers when required
        (
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
            ))
        )

        # 6. Disallow cross-feature `mod."feat/*"` option definitions and references
        (let
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

          crossFeatRefErrors =
            (lib.filesystem.listFilesRecursive commonDir ++ lib.filesystem.listFilesRecursive featuresDir)
            |> map toString
            |> builtins.filter (lib.hasSuffix ".nix")
            |> lib.concatMap (
              file: let
                inherit (expectedModFor file) label expectedMod;
              in
                extractFeatModRefs (builtins.readFile file)
                |> builtins.filter (ref: ref != expectedMod)
                |> map (ref: "${label}: references mod.\"${ref}\" (cross-feature mod option references are disallowed)")
            );
        in
          checkCrossFeatDefs "NixOS" allNixosEval.options.mod
          ++ checkCrossFeatDefs "Home-Manager" allHmEval.options.mod
          ++ crossFeatRefErrors)
      ]);
    in
      if errors == []
      then pkgs.emptyFile
      else throw "Module drift detected:\n- ${lib.concatStringsSep "\n- " errors}";
  };
}
