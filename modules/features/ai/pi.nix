/*
  feat/ai/pi

Enables Pi, the minimal agent harness.

Exposes:

- flake.homeModules."feat/ai/pi":
*/
{...}: let
  moduleName = "feat/ai/pi";
in {
  flake.homeModules."common/options" = {
    config,
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: let
    osProviders =
      if osConfig != null
      then osConfig.mod.ai.providers
      else {};
    providers = osProviders // config.mod.ai.providers;
    activeProviders = lib.filterAttrs (_: p: p.models != []) providers;
    providerNames = builtins.attrNames activeProviders;
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
    osProviders =
      if osConfig != null
      then osConfig.mod.ai.providers
      else {};
    providers = osProviders // config.mod.ai.providers;
    activeProviders = lib.filterAttrs (_: p: p.models != []) providers;
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
