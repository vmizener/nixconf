# Schema-driven TOML loader mapping `snake_case` TOML tables onto an `options`
# declaration tree while preserving dynamic `attrsOf` map keys and collecting
# schema validation assertions.
{lib}: let
  camelToSnake = str:
    builtins.split "([A-Z])" str
    |> map (
      p:
        if builtins.isList p
        then "_${lib.toLower (builtins.head p)}"
        else p
    )
    |> lib.concatStrings;

  hasWritable = v:
    if lib.isOption v
    then !((v.readOnly or false) || (v.internal or false))
    else if builtins.isAttrs v
    then
      builtins.any hasWritable (
        builtins.attrValues (lib.filterAttrs (k: _: !(lib.hasPrefix "_" k)) v)
      )
    else false;

  writableChildren = optSet:
    lib.filterAttrs (k: v: !(lib.hasPrefix "_" k) && hasWritable v) optSet;

  isSubmoduleType = t:
    t.name == "submodule" || (t ? functor && t.functor.name == "submodule");

  isAttrsOfType = t:
    t.name == "attrsOf" || (t ? functor && t.functor.name == "attrsOf");

  isListOfType = t:
    t.name == "listOf" || (t ? functor && t.functor.name == "listOf");
in {
  loadTomlFiles = {
    files,
    optSet,
    sourceLabel,
  }: let
    tomlConfigs = map lib.importTOML files;

    formatScope = pathPrefix:
      if pathPrefix == []
      then "top-level section(s)"
      else "[${lib.concatStringsSep "." pathPrefix}] key(s)";

    collectAssertions = pathPrefix: curOptSet: tables: let
      children = writableChildren curOptSet;
      allowedTomlKeys =
        builtins.attrNames children
        |> map camelToSnake
        |> builtins.sort builtins.lessThan;
      nonTables = builtins.filter (t: !(builtins.isAttrs t)) tables;
      attrTables = builtins.filter builtins.isAttrs tables;
      unknownKeys =
        lib.unique (lib.concatMap builtins.attrNames attrTables)
        |> builtins.filter (k: !(builtins.elem k allowedTomlKeys));
      tableLabel = "[${lib.concatStringsSep "." pathPrefix}]";
    in
      lib.optional (nonTables != []) {
        assertion = false;
        message = "${sourceLabel}: expected ${tableLabel} to be a TOML table";
      }
      ++ lib.optional (unknownKeys != []) {
        assertion = false;
        message = "${sourceLabel}: unexpected ${formatScope pathPrefix}: ${lib.concatStringsSep ", " unknownKeys} (allowed: ${lib.concatStringsSep ", " allowedTomlKeys})";
      }
      ++ lib.concatLists (
        lib.mapAttrsToList (
          nixKey: childOpt: let
            tomlKey = camelToSnake nixKey;
            vals =
              attrTables
              |> builtins.filter (t: t ? ${tomlKey})
              |> map (t: t.${tomlKey});
          in
            if vals == []
            then []
            else if !(lib.isOption childOpt)
            then collectAssertions (pathPrefix ++ [tomlKey]) childOpt vals
            else if isAttrsOfType childOpt.type
            then let
              elemType = childOpt.type.nestedTypes.elemType;
              badMaps = builtins.filter (v: !(builtins.isAttrs v)) vals;
              mapTables = builtins.filter builtins.isAttrs vals;
              entryKeys = lib.unique (lib.concatMap builtins.attrNames mapTables);
            in
              lib.optional (badMaps != []) {
                assertion = false;
                message = "${sourceLabel}: expected [${lib.concatStringsSep "." (pathPrefix ++ [tomlKey])}] to be a TOML table";
              }
              ++ lib.optionals (isSubmoduleType elemType) (
                lib.concatMap (
                  entryKey: let
                    entryVals =
                      mapTables
                      |> builtins.filter (m: m ? ${entryKey})
                      |> map (m: m.${entryKey});
                  in
                    collectAssertions (pathPrefix ++ [tomlKey entryKey]) (elemType.getSubOptions []) entryVals
                )
                entryKeys
              )
            else []
        )
        children
      );

    buildConfig = curOptSet: tables: let
      children = writableChildren curOptSet;
      attrTables = builtins.filter builtins.isAttrs tables;
    in
      builtins.mapAttrs (
        nixKey: childOpt: let
          tomlKey = camelToSnake nixKey;
          vals =
            attrTables
            |> builtins.filter (t: t ? ${tomlKey})
            |> map (t: t.${tomlKey});
        in
          if !(lib.isOption childOpt)
          then buildConfig childOpt vals
          else if isAttrsOfType childOpt.type
          then let
            elemType = childOpt.type.nestedTypes.elemType;
            mapTables = builtins.filter builtins.isAttrs vals;
            entryKeys = lib.unique (lib.concatMap builtins.attrNames mapTables);
          in
            if isSubmoduleType elemType
            then
              lib.mkIf (mapTables != []) (
                lib.genAttrs entryKeys (
                  entryKey: let
                    entryVals =
                      mapTables
                      |> builtins.filter (m: m ? ${entryKey})
                      |> map (m: m.${entryKey});
                  in
                    buildConfig (elemType.getSubOptions []) entryVals
                )
              )
            else if isListOfType elemType || isAttrsOfType elemType
            then lib.mkMerge mapTables
            else
              lib.mkIf (mapTables != []) (
                lib.foldl' (acc: m: acc // m) {} mapTables
                |> builtins.mapAttrs (_: lib.mkDefault)
              )
          else if isListOfType childOpt.type
          then lib.mkMerge vals
          else lib.mkIf (vals != []) (lib.mkDefault (lib.last vals))
      )
      children;
  in {
    assertions = collectAssertions [] optSet tomlConfigs;
    config = buildConfig optSet tomlConfigs;
  };
}
