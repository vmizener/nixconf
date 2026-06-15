{self, ...}: {
  flake.lib = {
    # Generates a standardized Flake module layout for a selector feature, consisting of:
    # 1. A base preset module (`feat/<featureName>`) that enables a default selection.
    # 2. An options module (`feat/<featureName>:options`) declaring the selection schema.
    #
    # Type: mkSelectorFeature :: {
    #   featureName :: String,
    #   defaultSelection :: String,
    #   target :: String,
    #   isMulti :: Boolean (Optional, default: false)
    # } -> AttrsOf Module
    #
    # Parameters:
    #   - featureName: The submodule name under `features.<featureName>` (e.g. "desktop-manager").
    #   - defaultSelection: The default choice activated when importing the base preset.
    #   - target: The flake output containing the modules (e.g. "nixosModules" or "homeModules").
    #   - isMulti: If true, allows selecting multiple options (`listOf str`).
    #              If false, enforces a single active choice (`str`).
    #
    # Example:
    #   flake.nixosModules = self.lib.mkSelectorFeature {
    #     featureName = "display-manager";
    #     defaultSelection = "ly";
    #     target = "nixosModules";
    #     isMulti = false;
    #   };
    mkSelectorFeature = {
      featureName,
      defaultSelection,
      target,
      isMulti ? false,
    }: let
      optPath = [
        "features"
        featureName
      ];
      featurePath = "feat/${featureName}";
    in {
      "${featurePath}" = {lib, ...}: {
        imports = [
          self.${target}."${featurePath}:options"
          self.${target}."${featurePath}/${defaultSelection}"
        ];
        config = lib.mkIf (!isMulti) {
          features.${featureName}.selected = lib.mkDefault defaultSelection;
        };
      };

      "${featurePath}:options" = {
        key = "${featurePath}:options";
        imports = [
          (
            {
              config,
              lib,
              ...
            }: let
              cfg = lib.getAttrFromPath optPath config;
            in {
              options.features.${featureName} = {
                available = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = "List of available options for ${featureName}";
                };
                selected = lib.mkOption {
                  type =
                    if isMulti
                    then lib.types.listOf lib.types.str
                    else lib.types.str;
                  default =
                    if isMulti
                    then []
                    else "";
                  description = "Active selection(s) for ${featureName}";
                };
              };

              config = {
                assertions = [
                  (
                    if isMulti
                    then {
                      assertion = lib.all (m: lib.elem m cfg.available) cfg.selected;
                      message = let
                        selected = lib.concatStringsSep ", " cfg.selected;
                        available = lib.concatStringsSep ", " cfg.available;
                      in "Selected ${featureName} '${selected}' contains unavailable options. Available: ${available}";
                    }
                    else {
                      assertion = cfg.selected == "" || lib.elem cfg.selected cfg.available;
                      message = let
                        selected = cfg.selected;
                        available = lib.concatStringsSep ", " cfg.available;
                      in "Selected ${featureName} '${selected}' is not available. Available: ${available}";
                    }
                  )
                ];
              };
            }
          )
        ];
      };
    };

    # Generates a standardized choice module for a selector feature (e.g. `feat/<featureName>/<selectionName>`).
    #
    # Automatically registers the choice under `available`, defaults itself under `selected` (when single-select),
    # and wraps the underlying module configuration so it only executes when this choice is active.
    #
    # Type: mkSelectorChoice :: {
    #   featureName :: String,
    #   selectionName :: String,
    #   module :: Module | (Args -> Module),
    #   target :: String (Optional, default: "nixosModules")
    # } -> AttrsOf Module
    #
    # Parameters:
    #   - featureName: The target selector submodule (e.g. "desktop-manager").
    #   - selectionName: The choice name (e.g. "niri").
    #   - module: The module definition or function to apply when this choice is active.
    #   - target: The flake output containing the options module (e.g. "nixosModules" or "homeModules").
    #
    # Note:
    #   Dynamic type inspection on `options.features.<featureName>.selected.default` is used to infer
    #   whether the selector is single-choice or multi-choice automatically.
    #
    # Example:
    #   flake.nixosModules = self.lib.mkSelectorChoice {
    #     featureName = "display-manager";
    #     selectionName = "ly";
    #     module = { services.displayManager.ly.enable = true; };
    #   };
    mkSelectorChoice = {
      featureName,
      selectionName,
      module,
      target,
    }: let
      featurePath = "feat/${featureName}";
      choicePath = "${featurePath}/${selectionName}";
    in {
      "${choicePath}" = {
        key = choicePath;
        imports = [
          self.${target}."${featurePath}:options"
          (
            {
              config,
              options,
              lib,
              pkgs,
              ...
            } @ args: let
              cfg = config.features.${featureName};
              opts = lib.getAttrFromPath ["features" featureName "selected"] options;
              isMulti = builtins.isList opts.default;
              isSelected =
                if isMulti
                then lib.elem selectionName cfg.selected
                else cfg.selected == selectionName;
              evaluated =
                if lib.isFunction module
                then module args
                else module;
            in {
              config = lib.mkMerge [
                {
                  features.${featureName}.available = [selectionName];
                }
                (
                  if isMulti
                  then {
                    features.${featureName}.selected = [selectionName];
                  }
                  else {
                    features.${featureName}.selected = lib.mkDefault selectionName;
                  }
                )
                (lib.mkIf isSelected (evaluated.config or evaluated))
              ];
              imports = evaluated.imports or [];
            }
          )
        ];
      };
    };
  };
}
