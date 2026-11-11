/*
  common/handlers

Priority-ranked registry for default XDG MIME applications and desktop UI/IPC
action handlers.

Exposes:

- flake.homeModules."common/handlers"
- flake.homeModules."common/options" (options.mod."common/handlers")
*/
{lib, ...}: let
  moduleName = "common/handlers";

  categories =
    import ./_categories.nix
    |> builtins.mapAttrs (
      _: {
        description,
        mimes ? [],
        actions ? {},
      }: {
        inherit description mimes;
        actions = builtins.mapAttrs (_: {description}: {inherit description;}) actions;
      }
    );

  sortEntries = entries:
    entries
    |> builtins.attrValues
    |> builtins.sort (
      a: b: a.priority < b.priority || (a.priority == b.priority && a.id < b.id)
    );
in {
  flake.homeModules."common/options" = {config, ...}: {
    options.mod.${moduleName} = import ./_options.nix {
      inherit categories lib sortEntries;
      added = config.mod.${moduleName}.add;
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.meta.imported = [moduleName];

    assertions =
      categories
      |> lib.mapAttrsToList (
        catName: cat:
          lib.mapAttrsToList (id: entry: let
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
          cfg.add.${catName}
      )
      |> lib.flatten;

    xdg = {
      mime.enable = true;
      mimeApps = {
        enable = true;
        associations.added = cfg.associations;
        defaultApplications =
          categories
          |> lib.mapAttrsToList (catName: cat: let
            desktops =
              cfg.add.${catName}
              |> sortEntries
              |> map (e: e.desktop)
              |> builtins.filter (d: d != null);
          in
            lib.optionalAttrs (cat.mimes != [] && desktops != []) (
              lib.genAttrs cat.mimes (_: desktops)
            ))
          |> lib.zipAttrsWith (_: lib.flatten);
      };
    };
  };
}
