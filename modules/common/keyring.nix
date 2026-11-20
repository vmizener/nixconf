/*
  common/keyring

Shared SecretService keyring broker across NixOS and Home-Manager (`common/keyring`),
decoupling keyring providers (e.g. `feat/system/keyring`) from PAM greeters, XDG desktop
portals, and credential consumers (`git`, `maestral`).

Exposes:

- flake.nixosModules."common/options" (options.mod."common/keyring")
- flake.nixosModules."common/keyring"
- flake.homeModules."common/options" (options.mod."common/keyring")
- flake.homeModules."common/keyring"
*/
{lib, ...}: let
  moduleName = "common/keyring";

  activeProviders = providers:
    providers
    |> builtins.attrValues
    |> builtins.filter (p: p.enable);

  sharedOptions = cfg: let
    providerSubmodule = lib.types.submodule ({name, ...}: {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether this keyring provider is active.";
        };
        id = lib.mkOption {
          type = lib.types.str;
          default = name;
          readOnly = true;
          description = "Identifier key of this keyring provider.";
        };
        portal = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "gnome-keyring";
          description = "XDG desktop portal backend name implementing `org.freedesktop.impl.portal.Secret` (or `null` if unsupported).";
        };
      };
    });
  in {
    providers = lib.mkOption {
      type = lib.types.attrsOf providerSubmodule;
      default = {};
      description = "Registered SecretService (`org.freedesktop.secrets`) keyring providers (at most one may be enabled per target).";
    };
    enable = lib.mkOption {
      type = lib.types.bool;
      default = activeProviders cfg.providers != [];
      defaultText = lib.literalExpression "activeProviders != []";
      readOnly = true;
      description = "Whether a SecretService keyring provider is active.";
    };
    provider = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = let
        active = activeProviders cfg.providers;
      in
        if active == []
        then null
        else (builtins.head active).id;
      defaultText = lib.literalExpression "activeProvider.id or null";
      readOnly = true;
      description = "Identifier of the active keyring provider (or `null` if none is enabled).";
    };
    portal = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = let
        active = activeProviders cfg.providers;
      in
        if active == []
        then null
        else (builtins.head active).portal;
      defaultText = lib.literalExpression "activeProvider.portal or null";
      readOnly = true;
      description = "XDG `Secret` portal backend name of the active keyring provider (or `null` if unset).";
    };
  };

  mkAssertions = cfg: let
    enabledIds = map (p: p.id) (activeProviders cfg.providers);
  in [
    {
      assertion = builtins.length enabledIds <= 1;
      message = ''mod."${moduleName}".providers: multiple keyring providers enabled (${lib.concatStringsSep ", " enabledIds}); at most one SecretService provider may be active.'';
    }
  ];
in {
  flake.nixosModules."common/options" = {config, ...}: {
    options.mod.${moduleName} =
      sharedOptions config.mod.${moduleName}
      // {
        pamServices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          apply = lib.unique;
          example = [
            "greetd"
            "ly"
          ];
          description = "PAM service names under `security.pam.services` that should unlock the active keyring on login.";
        };
      };
  };

  flake.homeModules."common/options" = {config, ...}: {
    options.mod.${moduleName} = sharedOptions config.mod.${moduleName};
  };

  flake.nixosModules.${moduleName} = {config, ...}: let
    cfg = config.mod.${moduleName};
  in {
    mod.meta.imported = [moduleName];
    assertions = mkAssertions cfg;

    xdg.portal.config.common = lib.optionalAttrs (cfg.portal != null) {
      "org.freedesktop.impl.portal.Secret" = lib.mkDefault cfg.portal;
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    osConfig ? null,
    ...
  }: let
    cfg = config.mod.${moduleName};
    mkOsDefault = lib.mkOverride 1100;
  in {
    mod =
      {
        meta.imported = [moduleName];
      }
      // lib.optionalAttrs (osConfig != null && osConfig.mod.meta.has moduleName) {
        ${moduleName}.providers =
          osConfig.mod.${moduleName}.providers
          |> lib.filterAttrs (_: p: p.enable)
          |> builtins.mapAttrs (_: p: {
            portal = mkOsDefault p.portal;
          });
      };

    assertions = mkAssertions cfg;
  };
}
