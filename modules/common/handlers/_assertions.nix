# Category registration completeness assertions for `common/handlers`.
{
  categories,
  cfg,
  lib,
  moduleName,
}:
categories
|> lib.mapAttrsToList (
  catName: cat:
    cfg.add.${catName}
    |> lib.filterAttrs (_: entry: entry.enable)
    |> lib.mapAttrsToList (id: entry: let
      loc = "mod.\"${moduleName}\".add.${catName}.${id}";
      hasAction =
        cat.actions
        != {}
        && lib.any (a: a != null) (builtins.attrValues entry.actions);
    in [
      {
        assertion = cat.mimes == [] || entry.desktop != null;
        message = "${loc}: MIME-backed category '${catName}' requires `desktop` to be set.";
      }
      {
        assertion = cat.mimes != [] || entry.cmd != null || hasAction;
        message =
          if cat.actions == {}
          then "${loc}: action category '${catName}' requires `cmd` to be set."
          else "${loc}: category '${catName}' requires `cmd` or at least one entry in `actions` to be set.";
      }
    ])
)
|> lib.flatten
