/*
  feat/ai/pi

Enables Pi, the minimal agent harness.

Exposes:

- flake.homeModules."feat/ai/pi":
*/
{...}: let
  moduleName = "feat/ai/pi";

  getActiveProviders = {
    config,
    lib,
    osConfig,
  }: let
    filterActive = lib.filterAttrs (_: p: p.models != []);
    osProviders =
      if osConfig != null
      then filterActive osConfig.mod.ai.providers
      else {};
    hmProviders = filterActive config.mod.ai.providers;
  in {
    # Right-biased merge: OS providers override HM providers on key collisions
    activeProviders = hmProviders // osProviders;
    # Prefer OS providers before HM providers when picking defaults
    providerNames = (builtins.attrNames osProviders) ++ (builtins.attrNames hmProviders);
  };
in {
  flake.homeModules."common/options" = {
    config,
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: let
    inherit (getActiveProviders {inherit config lib osConfig;}) activeProviders providerNames;
    hasProviders = providerNames != [];
    firstProvider = builtins.head providerNames;
  in {
    options.mod.${moduleName} = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.pi-coding-agent;
      };
      defaultProvider = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default =
          if hasProviders
          then firstProvider
          else null;
      };
      defaultModel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default =
          if hasProviders
          then builtins.head activeProviders.${firstProvider}.models
          else null;
      };
    };
  };
  flake.homeModules.${moduleName} = {
    config,
    lib,
    osConfig ? null,
    ...
  }: let
    cfg = config.mod.${moduleName};
    inherit (getActiveProviders {inherit config lib osConfig;}) activeProviders;
    hasProviders = activeProviders != {};
  in {
    mod.imported = [moduleName];
    programs.pi-coding-agent = {
      enable = true;
      package = cfg.package;
      settings =
        {
          defaultThinkingLevel = "medium";
        }
        // lib.optionalAttrs (cfg.defaultProvider != null) {
          defaultProvider = cfg.defaultProvider;
        }
        // lib.optionalAttrs (cfg.defaultModel != null) {
          defaultModel = cfg.defaultModel;
        };
      models = lib.mkIf hasProviders {
        providers = lib.mapAttrs (_: p:
          {
            inherit (p) api baseUrl;
            models = map (id: {inherit id;}) p.models;
          }
          // lib.optionalAttrs (p.apiKey != null) {
            inherit (p) apiKey;
          }
          // lib.optionalAttrs (p.compat != {}) {
            inherit (p) compat;
          })
        activeProviders;
      };
      context = ''
        Stay brief.
        Prefer small, reviewable changes.
        Inspect the repository before editing.
        Do not modify files outside the current project unless explicitly asked.
        Propose changes before making any.
        Run relevant tests after making changes.
      '';
    };
  };
}
