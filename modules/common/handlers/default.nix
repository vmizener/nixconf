/*
  common/handlers

Priority-ranked registry for default XDG MIME applications and desktop UI/IPC
action handlers.

Exposes:

- flake.homeModules."common/handlers"
- flake.homeModules."common/options" (options.mod."common/handlers")
*/
{...}: let
  moduleName = "common/handlers";
  categories = import ./_categories.nix;

  sortEntries = entries:
    entries
    |> builtins.attrValues
    |> builtins.sort (
      a: b: a.priority < b.priority || (a.priority == b.priority && a.id < b.id)
    );
in {
  flake.homeModules."common/options" = {
    config,
    lib,
    ...
  }: let
    handlerType = lib.types.submodule ({name, ...}: {
      options = {
        id = lib.mkOption {
          type = lib.types.str;
          default = name;
          readOnly = true;
          description = "Identifier key of this handler entry.";
        };
        priority = lib.mkOption {
          type = lib.types.int;
          default = 100;
          description = "Selection priority (lower numbers take precedence).";
        };
        label = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Human-readable name shown in hotkey overlays and desktop helpers.";
        };
        desktop = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "XDG .desktop entry filename (required for MIME-backed categories).";
        };
        cmd = lib.mkOption {
          type = lib.types.nullOr (lib.types.nonEmptyListOf lib.types.str);
          default = null;
          description = "Command argv list executed directly by keybindings or helpers.";
        };
      };
    });
  in {
    options.mod.${moduleName} = {
      add =
        lib.mapAttrs (
          _: cat:
            lib.mkOption {
              type = lib.types.attrsOf handlerType;
              default = {};
              description = "Registered candidate handlers for ${cat.description} (lower priority numbers take precedence).";
              example = lib.literalExpression ''
                {
                  helium = {
                    priority = 100;
                    label = "Helium";
                    desktop = "helium.desktop";
                    cmd = ["helium"];
                  };
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
      get =
        lib.mapAttrs (
          catName: cat:
            lib.mkOption {
              readOnly = true;
              description = "Winning highest-priority handler record for ${cat.description} (or null if unset).";
              default = let
                sorted = sortEntries config.mod.${moduleName}.add.${catName};
              in
                if sorted == []
                then null
                else builtins.head sorted;
            }
        )
        categories;
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};

    categoryDefaults =
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

    handlerAssertions =
      categories
      |> lib.mapAttrsToList (
        catName: cat:
          lib.mapAttrsToList (id: entry: let
            loc = "mod.\"${moduleName}\".add.${catName}.${id}";
          in [
            {
              assertion = cat.mimes == [] || entry.desktop != null;
              message = "${loc}: MIME-backed category '${catName}' requires `desktop` to be set.";
            }
            {
              assertion = cat.mimes != [] || entry.cmd != null;
              message = "${loc}: action category '${catName}' requires `cmd` to be set.";
            }
          ])
          cfg.add.${catName}
      )
      |> lib.flatten;
  in {
    mod.meta.imported = [moduleName];
    assertions = handlerAssertions;
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
