/*
  common/handlers

Priority-ranked registry for default XDG MIME applications and desktop UI/IPC
action handlers across NixOS and Home-Manager.

Exposes:

- flake.nixosModules."common/handlers"
- flake.nixosModules."common/options" (options.mod."common/handlers")
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
    |> builtins.filter (e: e.enable)
    |> builtins.sort (
      a: b: a.priority < b.priority || (a.priority == b.priority && a.id < b.id)
    );

  sortedDesktops = cfg: catName:
    cfg.add.${catName}
    |> sortEntries
    |> map (e: e.desktop)
    |> builtins.filter (d: d != null)
    |> lib.unique;

  mkDefaultApplications = cfg:
    categories
    |> lib.mapAttrsToList (catName: cat: let
      desktops = sortedDesktops cfg catName;
    in
      lib.optionalAttrs (cat.mimes != [] && desktops != []) (
        lib.genAttrs cat.mimes (_: desktops)
      ))
    |> lib.zipAttrsWith (_: lib.flatten);

  mkAssertions = cfg:
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
    |> lib.flatten;

  mkOsDefault = lib.mkOverride 1100;

  bridgeOsEntry = entry:
    {
      priority = mkOsDefault entry.priority;
      label = mkOsDefault entry.label;
      desktop = mkOsDefault entry.desktop;
      cmd = mkOsDefault entry.cmd;
    }
    // lib.optionalAttrs (entry ? actions) {
      actions =
        entry.actions
        |> lib.filterAttrs (_: a: a != null)
        |> builtins.mapAttrs (_: a: {
          label = mkOsDefault a.label;
          cmd = mkOsDefault a.cmd;
        });
    };

  optionsModule = {config, ...}: {
    options.mod.${moduleName} = import ./_options.nix {
      inherit categories lib sortEntries;
      added = config.mod.${moduleName}.add;
    };
  };
in {
  flake.nixosModules."common/options" = optionsModule;
  flake.homeModules."common/options" = optionsModule;

  flake.nixosModules.${moduleName} = {config, ...}: let
    cfg = config.mod.${moduleName};
    defaultApplications = mkDefaultApplications cfg;
    terminalDesktops = sortedDesktops cfg "terminal";
  in {
    mod.meta.imported = [moduleName];
    assertions = mkAssertions cfg;

    xdg = {
      mime = lib.mkIf (cfg.associations != {} || defaultApplications != {}) {
        enable = true;
        addedAssociations = cfg.associations;
        defaultApplications = builtins.mapAttrs (_: lib.mkDefault) defaultApplications;
      };
      terminal-exec = lib.mkIf (terminalDesktops != []) {
        enable = true;
        settings.default = lib.mkDefault terminalDesktops;
      };
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    osConfig ? null,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    terminalDesktops = sortedDesktops cfg "terminal";
  in {
    mod =
      {
        meta.imported = [moduleName];
      }
      // lib.optionalAttrs (osConfig != null && osConfig.mod.meta.has moduleName) (let
        osCfg = osConfig.mod.${moduleName};
      in {
        ${moduleName} = {
          add =
            osCfg.add
            |> builtins.mapAttrs (
              _: entries:
                entries
                |> lib.filterAttrs (_: e: e.enable)
                |> builtins.mapAttrs (_: bridgeOsEntry)
            );
          inherit (osCfg) associations;
        };
      });

    assertions = mkAssertions cfg;

    xdg = {
      mime.enable = true;
      mimeApps = {
        enable = true;
        associations.added = cfg.associations;
        defaultApplications = mkDefaultApplications cfg;
      };
      terminal-exec = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin && terminalDesktops != []) {
        enable = true;
        settings.default = terminalDesktops;
      };
    };
  };
}
