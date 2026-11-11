# Home-Manager option definitions for `common/handlers`.
{
  added,
  categories,
  lib,
  sortEntries,
}: let
  inherit (lib) mkOption types;

  actionSubmodule = parent: desc:
    types.submodule {
      options = {
        id = mkOption {
          type = types.str;
          default = parent.id;
          readOnly = true;
          description = "Inherited identifier key of the parent handler.";
        };
        priority = mkOption {
          type = types.int;
          default = parent.priority;
          readOnly = true;
          description = "Inherited selection priority of the parent handler.";
        };
        label = mkOption {
          type = types.str;
          default = parent.label;
          description = "Human-readable name shown in hotkey overlays and desktop helpers.";
        };
        cmd = mkOption {
          type = types.nonEmptyListOf types.str;
          description = "Command argv list executed for ${desc}.";
        };
      };
    };

  mkActionOption = parent: _: act:
    mkOption {
      type = types.nullOr (actionSubmodule parent act.description);
      default = null;
      description = "Action handler for ${act.description}.";
    };

  handlerSubmodule = actions:
    types.submodule (self: {
      options =
        {
          id = mkOption {
            type = types.str;
            default = self.name;
            readOnly = true;
            description = "Identifier key of this handler entry.";
          };
          priority = mkOption {
            type = types.int;
            default = 100;
            description = "Selection priority (lower numbers take precedence).";
          };
          label = mkOption {
            type = types.str;
            default = self.name;
            description = "Human-readable name shown in hotkey overlays and desktop helpers.";
          };
          desktop = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "XDG .desktop entry filename (required for MIME-backed categories).";
          };
          cmd = mkOption {
            type = types.nullOr (types.nonEmptyListOf types.str);
            default = null;
            description = "Command argv list executed directly by keybindings or helpers.";
          };
        }
        // lib.optionalAttrs (actions != {}) {
          actions = mkOption {
            default = {};
            description = "Named sub-action commands provided by this handler.";
            type = types.submodule {
              options = builtins.mapAttrs (mkActionOption self.config) actions;
            };
          };
        };
    });
in {
  add =
    categories
    |> builtins.mapAttrs (
      _: cat:
        mkOption {
          type = types.attrsOf (handlerSubmodule cat.actions);
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
    );

  associations = mkOption {
    type = types.attrsOf (types.listOf types.str);
    default = {};
    description = "Additional Open-With associations mapped to specific MIME types.";
  };

  get =
    categories
    |> builtins.mapAttrs (
      catName: cat:
        mkOption {
          readOnly = true;
          description = "Winning highest-priority handler record for ${cat.description} (or null if unset).";
          default = let
            sorted = sortEntries added.${catName};
          in
            if sorted == []
            then null
            else builtins.head sorted;
        }
    );
}
