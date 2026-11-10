/*
  common/mime

Sets up XDG MIME-type support and default application lists.

Exposes:

- flake.homeModules."common/mime"
- flake.homeModules."common/options" (options.mod."common/mime")
*/
{...}: let
  moduleName = "common/mime";
  categories = import ./_categories.nix;
in {
  flake.homeModules."common/options" = {
    config,
    lib,
    ...
  }: {
    options.mod.${moduleName} = {
      add =
        lib.mapAttrs (
          _: cat:
            lib.mkOption {
              type = lib.types.attrsOf lib.types.int;
              default = {};
              description = "Desktop entries mapped to priority numbers for ${cat.description} (lower numbers take precedence).";
              example = lib.literalExpression ''
                {
                  "helium.desktop" = 100;
                  "firefox.desktop" = 150;
                }
              '';
            }
        )
        categories;
      associations = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {};
        description = "Additional Open-With associations mapped to specific MIME types.";
      };
      defaultDesktop = lib.mkOption {
        default = mimeType: let
          entries = lib.toList (config.xdg.mimeApps.defaultApplications.${mimeType} or []);
        in
          if entries == []
          then null
          else builtins.head entries;
        description = "Return the highest-priority .desktop entry for a MIME type (or null if unset).";
        readOnly = true;
      };
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};

    sortEntries = entries:
      entries
      |> lib.mapAttrsToList (name: priority: {inherit name priority;})
      |> builtins.sort (
        a: b: a.priority < b.priority || (a.priority == b.priority && a.name < b.name)
      )
      |> map (e: e.name);

    categoryDefaults =
      categories
      |> lib.mapAttrsToList (catName: cat: let
        sorted = sortEntries cfg.add.${catName};
      in
        lib.optionalAttrs (sorted != []) (lib.genAttrs cat.mimes (_: sorted)))
      |> lib.zipAttrsWith (_: lib.flatten);
  in {
    mod.meta.imported = [moduleName];
    xdg = {
      mime.enable = true;
      mimeApps = {
        enable = true;
        defaultApplications = categoryDefaults;
        associations.added = cfg.associations;
      };
    };
  };
}
